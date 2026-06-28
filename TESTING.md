# Running Elevator Tests

This branch (`Elevator_golden`) contains the corrected implementation in `sources/`. The `tests/` folder is intentionally empty on this branch.

Use the `Elevator_test` branch for the populated test suite.

## Layout

```
sources/          Corrected RTL implementation
tests/            Empty on this branch
pyproject.toml    Python dependencies (cocotb, pytest)
SPEC.md           Design specification
```

## Setup

```bash
uv sync
```

## Verify with the test suite

Check out `Elevator_test`, replace its `sources/` files with the ones from this branch, then run:

```bash
uv run pytest tests/ -v
```

All tests should pass with the golden sources.
