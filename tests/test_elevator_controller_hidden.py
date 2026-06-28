"""Smoke-test the buggy sources RTL using the same cocotb cases as golden."""

from __future__ import annotations

import os

import pytest


@pytest.mark.parametrize("rtl_root", ["sources"])
def test_buggy_sources_runner(rtl_root: str, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ELEVATOR_RTL_ROOT", rtl_root)
    from test_elevator_controller import test_elevator_controller_runner

    test_elevator_controller_runner()
