"""Shared helpers for cocotb elevator tests."""

from __future__ import annotations

from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

NUM_FLOORS = 16
TOP_FLOOR = NUM_FLOORS - 1
NUM_LIFTS = 6


def apply_limits(dut) -> None:
    """Drive top/bottom limit sensors from the current floor."""
    floor = int(dut.current_floor.value)
    dut.top_limit.value = 1 if floor == TOP_FLOOR else 0
    dut.bottom_limit.value = 1 if floor == 0 else 0


async def start_clock(dut, period_ns: int = 10) -> Clock:
    clock = Clock(dut.clk, period_ns, unit="ns")
    clock.start(start_high=False)
    return clock


async def reset_controller(dut, cycles: int = 2) -> None:
    """Hold reset, then release and leave inputs in a safe idle state."""
    dut.req_valid.value = 0
    dut.req_floor.value = 0
    dut.req_cabin.value = 1
    dut.req_hall_up.value = 0
    dut.cabin_buttons.value = 0
    dut.hall_up_buttons.value = 0
    dut.hall_down_buttons.value = 0
    dut.emergency_stop.value = 0
    dut.door_obstructed.value = 0

    dut.reset.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.clk)
        apply_limits(dut)

    dut.reset.value = 0
    await RisingEdge(dut.clk)
    apply_limits(dut)


async def pulse_request(
    dut,
    floor: int,
    *,
    cabin: int = 1,
    hall_up: int = 0,
) -> None:
    """Serialized one-cycle request pulse (negedge-to-negedge)."""
    dut.req_valid.value = 0
    await FallingEdge(dut.clk)
    dut.req_floor.value = floor
    dut.req_cabin.value = cabin
    dut.req_hall_up.value = hall_up
    dut.req_valid.value = 1
    await FallingEdge(dut.clk)
    dut.req_valid.value = 0
    apply_limits(dut)


async def wait_cycles(dut, n: int) -> None:
    for _ in range(n):
        await RisingEdge(dut.clk)
        apply_limits(dut)


async def wait_for_floor(dut, floor: int, max_cycles: int = 500) -> None:
    """Wait until the car is idle at the requested floor."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        apply_limits(dut)
        if int(dut.current_floor.value) == floor and int(dut.idle.value) == 1:
            return
    raise TimeoutError(f"Car did not reach floor {floor} within {max_cycles} cycles")


async def wait_until_no_requests(dut, max_cycles: int = 800) -> None:
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        apply_limits(dut)
        if int(dut.pending_requests.value) == 0 and int(dut.idle.value) == 1:
            return
    raise TimeoutError("Pending requests did not clear")
