# Running Elevator Tests

This branch (`Elevator_baseline`) contains the starting implementation in `sources/` with hidden defects. The `tests/` folder is intentionally empty.

Use the `Elevator_test` branch for the populated test suite.

## Layout

```
sources/          RTL under test (baseline / buggy implementation)
tests/            Empty on this branch
pyproject.toml    Python dependencies (cocotb, pytest)
SPEC.md           Design specification
```

## Setup

```bash
uv sync
```
