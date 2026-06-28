# Elevator Control System — Design Specification

This document describes the RTL design: module hierarchy, interfaces, state machines, and control algorithms. It covers **design content only** (no testbench, simulation, or integration procedures).

---

## 1. Overview

The design is a **parameterized elevator control system** in two layers:

| Layer | Module(s) | Purpose |
|-------|-----------|---------|
| **Single-car controller** | `elevator_controller`, `Lift8` | One car: movement, doors, requests, emergency stop |
| **Multi-car bank** | `elevator_group`, `elevator_dispatch` | Four parallel cars with priority-based hall-call assignment |

**Default configuration:** 8 floors (`0` … `7`), 4 lifts, 10 clock cycles door-open time.

**Implementation style:** Fully synchronous — registered state in `always_ff`, next-state logic in `always_comb`.

---

## 2. Hierarchy

### 2.1 Single-car

```
                    ┌─────────────────────────────────────┐
  clk, reset ──────►│                                     │
  req_valid/floor ──►│         elevator_controller         ├──► door_open, idle
  cabin/hall btns ──►│  • Request queue (bitmap)           ├──► moving_up/down
  emergency_stop ───►│  • max/min request tracking         ├──► current_floor
  top/bottom limit ─►│  • 7-state FSM                      ├──► pending_requests
  door_obstructed ──►│  • Door timer + e-stop save/restore └──► service_dir_up/down
                    └─────────────────────────────────────┘
```

### 2.2 Multi-car

```
  Hall calls ──► FIFO queue ──► elevator_dispatch ──► selected lift (0..3)
        │                              │
        │                              ▼
        │              ┌─── elevator_controller (lift 0)
        │              ├─── elevator_controller (lift 1)
  Cabin buttons ───────├─── elevator_controller (lift 2)
  (per lift)           └─── elevator_controller (lift 3)
```

**Signal routing**
- **Hall calls** → FIFO → dispatcher → one-cycle `req_valid` pulse to the chosen lift.
- **Cabin buttons** → connected directly to that lift (bypass dispatch).

---

## 3. Module: `elevator_controller`

Single-car controller. Scales by changing `NUM_FLOORS`; FSM structure is unchanged.

### 3.1 Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `NUM_FLOORS` | 8 | Floors `0` … `NUM_FLOORS-1` |
| `DOOR_OPEN_CYCLES` | 10 | Door-open duration in clock cycles |
| `FLOOR_W` | `$clog2(NUM_FLOORS)` | Floor address width |
| `DOOR_TIMER_W` | derived | Door countdown register width |

### 3.2 Interface

**Clock / reset:** `clk`, `reset` (async active-high)

**Requests (serialized and parallel inputs are OR-ed)**

| Port | Dir | Description |
|------|-----|-------------|
| `req_valid` | in | One-cycle pulse on button press |
| `req_floor[FLOOR_W-1:0]` | in | Target floor (serialized path) |
| `req_cabin` | in | `1` = cabin button; `0` = hall call |
| `req_hall_up` | in | Hall direction: `1` = up, `0` = down |
| `cabin_buttons[NUM_FLOORS-1:0]` | in | Level-sensitive cabin buttons |
| `hall_up_buttons[NUM_FLOORS-1:0]` | in | Level-sensitive hall up buttons |
| `hall_down_buttons[NUM_FLOORS-1:0]` | in | Level-sensitive hall down buttons |

**Safety**

| Port | Description |
|------|-------------|
| `emergency_stop` | Stop car, close doors, latch and save state |
| `top_limit` | Inhibit upward motion |
| `bottom_limit` | Inhibit downward motion |
| `door_obstructed` | Reload door-open timer while asserted |

**Outputs**

| Port | Description |
|------|-------------|
| `door_open` | Doors open |
| `idle` | Not traveling between floors |
| `moving_up` / `moving_down` | Active during `ST_MOVING_UP` / `ST_MOVING_DOWN` |
| `service_dir_up` / `service_dir_down` | Preferred service direction |
| `current_floor[FLOOR_W-1:0]` | Present floor |
| `pending_requests[NUM_FLOORS-1:0]` | Pending-stop bitmap |
| `max_request` / `min_request` | Highest / lowest pending floor |
| `estop_latched` | Emergency stop active |
| `fsm_state[2:0]` | Current FSM state encoding |

### 3.3 Internal state

| Structure | Role |
|-----------|------|
| `pending_requests[i]` | Floor `i` still needs service |
| `max_request` | Upper bound of pending stops; rescanned after each clear |
| `min_request` | Lower bound of pending stops; rescanned after each clear |
| `service_dir_up/down` | Direction flags; after reset: up=`1`, down=`0` |
| Sentinels (no requests) | `max_request = 0`, `min_request = NUM_FLOORS-1` |

### 3.4 FSM

| Encoding | State | Description |
|----------|-------|-------------|
| 0 | `ST_RESET` | Reset held; exit when `reset` deasserts |
| 1 | `ST_DOOR_CLOSED_IDLE` | Stopped, doors closed, selecting next move |
| 2 | `ST_DOOR_OPEN_IDLE` | Stopped, doors open, timer counting |
| 3 | `ST_MOVING_UP` | Moving up one floor per clock if no stop here |
| 4 | `ST_MOVING_DOWN` | Moving down one floor per clock if no stop here |
| 5 | `ST_UP_DIR_SETTER` | At upper sweep bound; set direction up, open if requested |
| 6 | `ST_DOWN_DIR_SETTER` | At lower sweep bound; set direction down, open if requested |

**Key transitions**

| From | Condition | To | Action |
|------|-----------|-----|--------|
| `ST_DOOR_CLOSED_IDLE` | Request at `current_floor` | `ST_DOOR_OPEN_IDLE` | Open doors, clear bit, start timer |
| `ST_DOOR_CLOSED_IDLE` | Pending above, direction up | `ST_MOVING_UP` | — |
| `ST_DOOR_CLOSED_IDLE` | Pending below, direction down | `ST_MOVING_DOWN` | — |
| `ST_DOOR_CLOSED_IDLE` | `max_request == current_floor` | `ST_DOWN_DIR_SETTER` | Reverse to down |
| `ST_DOOR_CLOSED_IDLE` | `min_request == current_floor` | `ST_UP_DIR_SETTER` | Reverse to up |
| `ST_MOVING_UP/DOWN` | Request at `current_floor` | `ST_DOOR_OPEN_IDLE` | Stop, open, clear, timer |
| `ST_MOVING_UP/DOWN` | No stop, limit OK | same | ±1 floor |
| `ST_DOOR_OPEN_IDLE` | Timer expired | `ST_DOOR_CLOSED_IDLE` | Close doors |
| any (normal) | `emergency_stop` | `ST_DOOR_CLOSED_IDLE` | Save state/direction, hold |
| e-stop latched | `emergency_stop` deassert | saved state | Restore and resume |

### 3.5 Request acceptance

New requests set bits in `pending_requests` and update bounds.

**Hall-call gating while moving:**

| Car state | Accepted hall calls |
|-----------|---------------------|
| Idle | All |
| Moving up | Up-calls above `current_floor` |
| Moving down | Down-calls below `current_floor` |
| Cabin (any time) | Always |

### 3.6 Movement algorithm

Direction-persistent, proximity-based scheduling:

1. Move in the current direction, stopping at every floor with a pending request.
2. Continue until the directional sweep bound (`max_request` going up, `min_request` going down).
3. Reverse direction at the bound via the direction-setter states.
4. Nearest-in-path service follows naturally from floor-by-floor travel (no separate FCFS queue).

### 3.7 Door logic

- Arrival at a requested floor → `door_open=1`, clear request, load timer with `DOOR_OPEN_CYCLES`.
- Timer counts down each clock; at zero → doors close, return to `ST_DOOR_CLOSED_IDLE`.
- `door_obstructed` during open → reload timer.

### 3.8 Emergency stop

1. Assert: latch e-stop, save FSM state and `service_dir_up/down`, force idle with doors closed.
2. Hold while asserted.
3. Deassert: restore saved direction and FSM state.

---

## 4. Module: `Lift8`

Compatibility wrapper around `elevator_controller` (legacy `Design.sv` port names).

| Port | Mapping |
|------|---------|
| `req_floor[2:0]` | Edge-detected as `req_valid`; always treated as cabin call |
| `idle`, `door`, `Up`, `Down` | 2-bit `{1'b0, signal}` |
| `requests[7:0]` | `pending_requests` |
| `top_limit` / `bottom_limit` | Derived from `current_floor == 7` / `== 0` |

Fixed at 8 floors. For hall-call behaviour, instantiate `elevator_controller` directly.

---

## 5. Module: `elevator_dispatch`

Combinational scorer plus round-robin tie-break. Selects the lift with the **lowest score** for one hall call.

### 5.1 Score bands

| Band | Condition |
|------|-----------|
| 0 | Idle at call floor |
| 1 | Idle elsewhere — metric: distance ≪ 2 + pending count |
| 2 | Moving favorably toward call — metric: distance ≪ 1 + pending count |
| 3 | Unfavorable direction or heavy load — metric: distance ≪ 3 + load penalty |
| `all 1`s | `estop_latched` — excluded |

**Tie-break:** `rr_ptr` rotates after each valid assignment.

### 5.2 Favorable movement

| Call vs car | Call type | Favorable when |
|-------------|-----------|----------------|
| Above | Up | `moving_up` or `service_dir_up`, not moving down |
| Below | Down | `moving_down` or `service_dir_down`, not moving up |
| Same floor | Either | Always |

### 5.3 Interface

| Port | Description |
|------|-------------|
| `call_floor`, `call_up`, `call_valid` | Hall call to score |
| `lift_floor[i]`, `lift_idle[i]`, `lift_moving_up/down[i]` | Per-lift motion |
| `lift_dir_up/down[i]` | Per-lift service direction |
| `lift_estop[i]`, `lift_pending[i]` | Availability and load |
| `selected_lift[LIFT_W-1:0]` | Winning lift index |
| `assign_valid` | Valid winner exists |
| `lift_score[i]`, `selected_score` | Per-lift and winning scores |

---

## 6. Module: `elevator_group`

Top level: `NUM_LIFTS` instances of `elevator_controller` plus hall-call queue and dispatch.

### 6.1 Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `NUM_LIFTS` | 4 | Parallel cars |
| `NUM_FLOORS` | 8 | Floors per car |
| `DOOR_OPEN_CYCLES` | 10 | Per-car door time |
| `HALL_QUEUE_DEPTH` | 8 | Hall-call FIFO depth |

### 6.2 Hall-call inputs

| Source | Mechanism |
|--------|-----------|
| Serialized | `hall_req_valid` + `hall_req_floor` + `hall_req_up` |
| Parallel up | Rising edge on `hall_up_buttons[f]` |
| Parallel down | Rising edge on `hall_down_buttons[f]` |

Duplicate `{floor, direction}` entries are not enqueued twice. FIFO overflow drops new entries (`hall_queue_full`).

### 6.3 Dispatch FSM

| State | Behaviour |
|-------|-----------|
| `DS_IDLE` | Wait for non-empty queue → `DS_ASSIGN` |
| `DS_ASSIGN` | Run `elevator_dispatch`, pulse selected lift, dequeue head; stay in `DS_ASSIGN` if queue remains |

### 6.4 Interface (group-level)

**Inputs:** hall-call ports above; `cabin_buttons[NUM_LIFTS][NUM_FLOORS]`; per-lift `emergency_stop`, `door_obstructed`.

**Outputs (per lift `i`):** same as `elevator_controller`.

**Dispatch status:** `last_assigned_lift`, `last_assigned_floor`, `last_assigned_up`, `hall_queue_full`, `hall_queue_count`.

---

## 7. Design assumptions

| Topic | Assumption |
|-------|------------|
| Clock | One floor step per clock while moving (behavioural travel model) |
| Reset | Async assert; deterministic init |
| Serialized requests | Single-cycle `req_valid` pulse |
| Doors | Single `door_open` flag; no separate door motor FSM |
| Multi-car | Each lift maintains an independent `current_floor` |
| Shafts | No inter-lift collision avoidance |

---

## 8. Design scope

The RTL **includes:**
- Parameterized floor count and multi-car dispatch
- Direction-aware request filtering and sweep scheduling
- Door timer and obstruction reload
- Emergency stop with state/direction save and restore
- Limit-sensor gating

The RTL **does not include:**
- Motor drive / PWM / acceleration profiles
- Shared-shaft or anti-collision logic between cars
- External back-pressure when the hall FIFO is full
- Persistent hall-lamp or button-latch outputs
