"""Safe importlib loading for scripts run as files (Python 3.11+ dataclass)."""
from __future__ import annotations

import importlib.util
import sys
from types import ModuleType


def exec_module_from_spec(spec: importlib.machinery.ModuleSpec) -> ModuleType:
    """
    Register module in sys.modules before exec_module.

    On Python 3.11+, @dataclass resolves annotations via sys.modules[cls.__module__];
    loading without registration raises AttributeError on PairSpec-like classes.
    """
    name = spec.name
    existing = sys.modules.get(name)
    if existing is not None:
        return existing
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    try:
        spec.loader.exec_module(mod)
    except Exception:
        sys.modules.pop(name, None)
        raise
    return mod
