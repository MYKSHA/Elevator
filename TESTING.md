# Running Elevator Tests

This branch (`Elevator_test`) contains the full cocotb/pytest suite in `tests/` and the baseline implementation in `sources/`.

**Expected result on this branch:** tests **fail** against the baseline RTL because the implementation contains hidden defects. Use the `Elevator_golden` branch for the corrected implementation.

## Setup

```bash
uv sync
```

## Run all tests

```bash
uv run pytest tests/ -v
```

## Run individual suites

```bash
uv run pytest tests/test_elevator_controller.py -v
uv run pytest tests/test_elevator_group.py -v
uv run pytest tests/test_bug_reveal.py -v
```

## Test files

| File | Purpose |
|------|---------|
| `tests/test_elevator_controller.py` | Single-car regression (11 tests) |
| `tests/test_elevator_group.py` | 6-lift group regression (6 tests) |
| `tests/test_bug_reveal.py` | Targeted tests that expose hidden bugs (3 tests) |

RTL is read from `sources/` by default. Override with `ELEVATOR_RTL_ROOT=sources` if needed.

## Notes

- Simulation artifacts: `sim_build/` (gitignored)
- Pytest cache: `.pytest_cache/` (gitignored)
