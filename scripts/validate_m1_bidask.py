#!/usr/bin/env python3
"""Validate M1 bid/ask CSV files from export_m1_bidask.mq5."""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd


def load_bars(path: Path | str) -> pd.DataFrame:
    raise NotImplementedError


def check_bars(df: pd.DataFrame) -> list[str]:
    raise NotImplementedError


def summarise(df: pd.DataFrame) -> dict:
    raise NotImplementedError


def main(argv: list[str] | None = None) -> int:
    raise NotImplementedError


if __name__ == "__main__":
    raise SystemExit(main())
