#!/usr/bin/env python3
"""Generate Phase-1 refactored V2 EAs alongside originals (no in-place edits).

Outputs:
  ea/fxmatrix_v2_ref.mq5
  ea/fxmatrix_v2_eurusd_ref.mq5
  ea/fxmatrix_v2_eurgbp_ref.mq5
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EA = ROOT / "ea"

SPECS = {
    "gbpusd": {
        "src": EA / "fxmatrix_v2.mq5",
        "out": EA / "fxmatrix_v2_ref.mq5",
        "preset": "V2_PRESET_GBPUSD",
        "title": "fxmatrix_v2_ref.mq5 — Phase 1 refactor (GBPUSD preset, parity target: fxmatrix_v2.mq5)",
        "version": "2.24",
        "extra_inputs": "",
        "init_print": "fxmatrix_v2_ref init",
        "has_cap": True,
    },
    "eurusd": {
        "src": EA / "fxmatrix_v2_eurusd.mq5",
        "out": EA / "fxmatrix_v2_eurusd_ref.mq5",
        "preset": "V2_PRESET_EURUSD",
        "title": "fxmatrix_v2_eurusd_ref.mq5 — Phase 1 refactor (EURUSD preset, parity: fxmatrix_v2_eurusd.mq5)",
        "version": "1.01",
        "extra_inputs": "",
        "init_print": "fxmatrix_v2_eurusd_ref init",
        "has_cap": False,
    },
    "eurgbp": {
        "src": EA / "fxmatrix_v2_eurgbp.mq5",
        "out": EA / "fxmatrix_v2_eurgbp_ref.mq5",
        "preset": "V2_PRESET_EURGBP",
        "title": "fxmatrix_v2_eurgbp_ref.mq5 — Phase 1 refactor (EURGBP preset, parity: fxmatrix_v2_eurgbp.mq5)",
        "version": "1.01",
        "extra_inputs": (
            'input string InpLegAC = "EURUSD";  // Triad leg A vs USD (AC)\n'
            'input string InpLegBC = "GBPUSD";  // Triad leg B vs USD (BC)\n'
        ),
        "init_print": "fxmatrix_v2_eurgbp_ref init AB-signal",
        "has_cap": True,
    },
}


def extract_function(body: str, name: str) -> str:
    start = body.find(f"bool {name}(double &")
    if start < 0:
        return body
    brace = 0
    i = body.find("{", start)
    for j in range(i, len(body)):
        if body[j] == "{":
            brace += 1
        elif body[j] == "}":
            brace -= 1
            if brace == 0:
                chunk = body[start : j + 1]
                return body.replace(chunk, "", 1)
    raise ValueError(f"Unclosed function {name}")


def build_header(spec: dict) -> str:
    cap_input = ""
    cap_include = ""
    cap_global = ""
    if spec["has_cap"]:
        cap_input = "input int    InpGbpCapThreshold   = 0;    // 0=off; block widening adds when |net|>N\n"
        cap_include = '#include "fxmatrix_v2_cross_exposure_cap.mqh"\n'
        cap_global = "V2CrossExposureCapConfig g_v2_cross_cap;\n"

    return f"""//+------------------------------------------------------------------+
//| {spec['title']}
//| Generated — does NOT replace deployed production .mq5 sources.    |
//+------------------------------------------------------------------+
#property copyright "fxmatrix"
#property version   "{spec['version']}"
#property strict

#define {spec['preset']}
#include "fxmatrix_v2_pair_config.mqh"
#include "fxmatrix_v2_logic_r1.mqh"
#include "fxmatrix_v2_signal.mqh"
#include "fxmatrix_v2_exits_r1.mqh"
#include "fxmatrix_v2_telemetry.mqh"
{cap_include}
input double InpQuoteSpread       = 0.0004;
input double InpSpreadMultiplier  = 0.500;
input double InpAddPipsFloor      = 9.0;
input double InpExitPips          = 3.0;
input double InpWidenRatio        = 1.304;
input double InpAddPipsCeiling    = 1000.0;
input double InpLotSize           = 0.01;
input int    InpMaxLayers         = 20;
{cap_input}input bool   InpVerboseLog        = true;
{spec['extra_inputs']}input bool   EnableTelemetry      = false;
input string TelemetryURL         = "https://pipshed.com/api/telemetry/push";
input string TelemetryAPIKey      = "";
input int    TelemetryIntervalSec = 60;

#include "fxmatrix_v2_signal_dispatch.mqh"

{cap_global}"""


def transform_body(body: str, spec: dict) -> str:
    body = extract_function(body, "Long_ComputeBidSignal")
    body = extract_function(body, "Short_ComputeOfferSignal")

    if spec["has_cap"]:
        body = body.replace(
            'V2_GbpCapBlocksNewAdd("GBPUSD", true, InpGbpCapThreshold)',
            "V2_CrossCapBlocksNewAdd(g_v2_cross_cap, true)",
        )
        body = body.replace(
            'V2_GbpCapBlocksNewAdd("GBPUSD", false, InpGbpCapThreshold)',
            "V2_CrossCapBlocksNewAdd(g_v2_cross_cap, false)",
        )
        body = body.replace(
            "V2_GbpCapBlocksNewAdd(V2_PAIR_LABEL, true, InpGbpCapThreshold)",
            "V2_CrossCapBlocksNewAdd(g_v2_cross_cap, true)",
        )
        body = body.replace(
            "V2_GbpCapBlocksNewAdd(V2_PAIR_LABEL, false, InpGbpCapThreshold)",
            "V2_CrossCapBlocksNewAdd(g_v2_cross_cap, false)",
        )
        body = body.replace("V2_GbpCapRecordBlock()", "V2_CrossCapRecordBlock()")
        body = body.replace(
            'V2_GbpCapSyncInstance("GBPUSD", true,',
            "V2_CrossCapSyncInstance(g_v2_cross_cap, true,",
        )
        body = body.replace(
            'V2_GbpCapSyncInstance("GBPUSD", false,',
            "V2_CrossCapSyncInstance(g_v2_cross_cap, false,",
        )
        body = body.replace(
            "V2_GbpCapSyncInstance(V2_PAIR_LABEL, true,",
            "V2_CrossCapSyncInstance(g_v2_cross_cap, true,",
        )
        body = body.replace(
            "V2_GbpCapSyncInstance(V2_PAIR_LABEL, false,",
            "V2_CrossCapSyncInstance(g_v2_cross_cap, false,",
        )
        body = body.replace("V2_GbpNetExposure()", "V2_CrossCapNetExposure(g_v2_cross_cap)")

        oninit_old = """   Long_OnInit();
   Short_OnInit();
   V2_GbpCapSyncInstance("GBPUSD", true, ArraySize(g_long_layers));
   V2_GbpCapSyncInstance("GBPUSD", false, ArraySize(g_short_layers));
   GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0.0);"""
        oninit_new = """   Long_OnInit();
   Short_OnInit();
   V2_CrossCapInitGbpTriadLegacy(g_v2_cross_cap, V2_PAIR_LABEL, InpGbpCapThreshold);
   V2_CrossCapSyncInstance(g_v2_cross_cap, true, ArraySize(g_long_layers));
   V2_CrossCapSyncInstance(g_v2_cross_cap, false, ArraySize(g_short_layers));
   GlobalVariableSet(V2_CROSS_CAP_TRIGGERS_GV, 0.0);"""
        body = body.replace(oninit_old, oninit_new)

        oninit_old2 = """   Long_OnInit();
   Short_OnInit();
   V2_GbpCapSyncInstance(V2_PAIR_LABEL, true, ArraySize(g_long_layers));
   V2_GbpCapSyncInstance(V2_PAIR_LABEL, false, ArraySize(g_short_layers));
   GlobalVariableSet("V2GBP_CAP_TRIGGERS", 0.0);"""
        body = body.replace(oninit_old2, oninit_new)

    # Normalize magic literals in GBPUSD source to macros (ref only)
    body = body.replace("20260901", "MM_LONG_V2")
    body = body.replace("20260902", "MM_SHORT_V2")

    body = body.replace(
        'Print("INFO: fxmatrix_v2 init',
        f'Print("INFO: {spec["init_print"]}',
    )
    body = body.replace(
        'Print("INFO: fxmatrix_v2_eurusd init',
        f'Print("INFO: {spec["init_print"]}',
    )
    body = body.replace(
        'Print("INFO: fxmatrix_v2_eurgbp init AB-signal',
        f'Print("INFO: {spec["init_print"]}',
    )

    return body


def build_one(key: str, spec: dict) -> None:
    text = spec["src"].read_text(encoding="utf-8")
    struct_idx = text.index("struct LongV2Layer")
    body = text[struct_idx:]
    body = transform_body(body, spec)
    out = build_header(spec) + body
    spec["out"].write_text(out, encoding="utf-8")
    print(f"Wrote {spec['out']} ({spec['out'].stat().st_size} bytes)")


def main() -> None:
    for key, spec in SPECS.items():
        build_one(key, spec)


if __name__ == "__main__":
    main()
