# Running Elevator Tests

Tests use cocotb + pytest. RTL is selected with the `ELEVATOR_RTL_ROOT` environment variable.

| Folder     | Role       |
|------------|------------|
| `golden/`  | Clean RTL  |
| `sources/` | Buggy RTL  |

## Setup (once)

```bash
cd /Users/om/RVEGA/ELEVATOR/Elevator
uv sync
```

## Golden (clean RTL)

Main tests default to `golden/`:

```bash
uv run pytest tests/ -v
```

Or explicitly:

```bash
ELEVATOR_RTL_ROOT=golden uv run pytest tests/ -v
```

Individual suites:

```bash
# Single-car controller (11 cocotb tests)
ELEVATOR_RTL_ROOT=golden uv run pytest tests/test_elevator_controller.py -v

# 6-lift group (6 cocotb tests)
ELEVATOR_RTL_ROOT=golden uv run pytest tests/test_elevator_group.py -v

# Bug-reveal tests (should PASS on golden)
ELEVATOR_RTL_ROOT=golden uv run pytest tests/test_bug_reveal.py -v
```

## Sources (buggy RTL)

```bash
ELEVATOR_RTL_ROOT=sources uv run pytest tests/ -v
```

Individual suites:

```bash
# Main regression (should PASS — bugs are hidden from these tests)
ELEVATOR_RTL_ROOT=sources uv run pytest tests/test_elevator_controller.py -v
ELEVATOR_RTL_ROOT=sources uv run pytest tests/test_elevator_group.py -v

# Bug-reveal (should FAIL — exposes the 3 hidden bugs)
ELEVATOR_RTL_ROOT=sources uv run pytest tests/test_bug_reveal.py -v

# Smoke test for sources only (always uses sources/)
uv run pytest tests/test_elevator_controller_hidden.py -v
```

## Quick reference

| Command | RTL | Expected |
|---------|-----|----------|
| `uv run pytest tests/ -v` | golden (default) | All pass |
| `ELEVATOR_RTL_ROOT=sources uv run pytest tests/test_elevator_controller.py tests/test_elevator_group.py -v` | sources | Regression passes |
| `ELEVATOR_RTL_ROOT=sources uv run pytest tests/test_bug_reveal.py -v` | sources | Fails (bugs exposed) |
| `uv run pytest tests/test_elevator_controller_hidden.py -v` | sources | Regression passes |

## Optional: verbose simulator logs

```bash
ELEVATOR_RTL_ROOT=golden uv run pytest tests/test_elevator_controller.py -v --log-cli-level=INFO
```

## Test files

| File | Purpose |
|------|---------|
| `tests/test_elevator_controller.py` | Single-car regression (default: golden) |
| `tests/test_elevator_group.py` | 6-lift group regression (default: golden) |
| `tests/test_bug_reveal.py` | Targeted tests for hidden bugs (default: sources) |
| `tests/test_elevator_controller_hidden.py` | Smoke-test sources with main controller suite |

## Notes

- `ELEVATOR_RTL_ROOT` must be `golden` or `sources` (paths are resolved from the project root).
- `test_elevator_controller_hidden.py` always forces `sources`, regardless of your shell env.
- Simulation artifacts go to `sim_build/`; pytest cache to `.pytest_cache/` (both gitignored).
