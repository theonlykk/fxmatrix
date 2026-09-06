//+------------------------------------------------------------------+
//| grind_config.mqh — init-time resolved configuration dump         |
//+------------------------------------------------------------------+
#ifndef GRIND_CONFIG_MQH
#define GRIND_CONFIG_MQH

//+------------------------------------------------------------------+
string Grind_ConfigTelemetryKeyStatus(const string api_key)
{
   return (api_key != "" ? "SET" : "MISSING");
}

//+------------------------------------------------------------------+
string Grind_ConfigDumpString(const ulong magic,
                              const string slot,
                              const string symbol,
                              const double width_pips,
                              const double add_pips,
                              const double exit_pips,
                              const int max_layers,
                              const double stranded_thresh_pips,
                              const double deadband_pips,
                              const double lots,
                              const string cap_leg_a,
                              const string cap_leg_b,
                              const double cap_leg_a_thresh,
                              const double cap_leg_b_thresh,
                              const string telemetry_instance,
                              const bool verbose_log,
                              const string config_warning,
                              const bool enable_telemetry,
                              const string telemetry_url,
                              const string telemetry_api_key,
                              const int telemetry_interval_sec)
{
   const string tel_on_off = enable_telemetry ? "on" : "off";
   const string key_status = Grind_ConfigTelemetryKeyStatus(telemetry_api_key);

   return StringFormat(
      "fxgrind CONFIG "
      "InpMagic=%s InpSlot=%s symbol=%s "
      "InpWidthPips=%.4f InpAddPips=%.4f InpExitPips=%.4f "
      "InpMaxLayers=%d InpStrandedThreshPips=%.4f InpDeadbandPips=%.4f InpLots=%.4f "
      "InpCapLegA=%s InpCapLegB=%s InpCapLegAThresh=%.4f InpCapLegBThresh=%.4f "
      "InpTelemetryInstance=%s InpVerboseLog=%s InpConfigWarning=%s "
      "telemetry=%s url=%s key=%s interval=%d",
      IntegerToString((long)magic),
      slot,
      symbol,
      width_pips,
      add_pips,
      exit_pips,
      max_layers,
      stranded_thresh_pips,
      deadband_pips,
      lots,
      cap_leg_a,
      cap_leg_b,
      cap_leg_a_thresh,
      cap_leg_b_thresh,
      telemetry_instance,
      verbose_log ? "true" : "false",
      config_warning,
      tel_on_off,
      telemetry_url,
      key_status,
      telemetry_interval_sec
   );
}

#endif // GRIND_CONFIG_MQH
