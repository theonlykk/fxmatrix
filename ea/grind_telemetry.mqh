//+------------------------------------------------------------------+
//| grind_telemetry.mqh — per-instance heartbeat for pipshed         |
//+------------------------------------------------------------------+
#ifndef GRIND_TELEMETRY_MQH
#define GRIND_TELEMETRY_MQH

#include "grind_api_counter.mqh"

//+------------------------------------------------------------------+
void Grind_TelemetryEmit(const string instance_name,
                         const string event,
                         const string detail_json = "{}")
{
   Print("TELEM|", instance_name, "|", event, "|", detail_json);
}

//+------------------------------------------------------------------+
void Grind_TelemetryCritical(const string instance_name,
                             const string event,
                             const string detail = "")
{
   string detail_json = "{\"detail\":\"" + detail + "\"}";
   Grind_TelemetryEmit(instance_name, "CRITICAL_" + event, detail_json);
}

//+------------------------------------------------------------------+
string Grind_TelemetryHeartbeatJson(const string instance_name,
                                    const int open_layers_long,
                                    const int open_layers_short,
                                    const int fills,
                                    const int scalps,
                                    const bool cap_blocked,
                                    const bool halted,
                                    const string halt_reason,
                                    const bool recon_ok,
                                    const bool invariant_ok,
                                    const double cap_leg_a,
                                    const double cap_leg_b,
                                    const double cap_total_leg_a,
                                    const double cap_total_leg_b,
                                    const bool peer_read_failed)
{
   return StringFormat(
      "{\"instance\":\"%s\",\"open_layers_long\":%d,\"open_layers_short\":%d,"
      "\"fills\":%d,\"scalps\":%d,\"api_count\":%d,\"api_counter_broken\":%s,"
      "\"cap_blocked\":%s,\"halted\":%s,\"halt_reason\":\"%s\","
      "\"recon_ok\":%s,\"invariant_ok\":%s,\"cap_leg_a\":%.4f,\"cap_leg_b\":%.4f,"
      "\"cap_total_leg_a\":%.4f,\"cap_total_leg_b\":%.4f,"
      "\"peer_read_failed\":%s}",
      instance_name,
      open_layers_long,
      open_layers_short,
      fills,
      scalps,
      Grind_ApiCounterRead(),
      g_grind_api_counter_broken ? "true" : "false",
      cap_blocked ? "true" : "false",
      halted ? "true" : "false",
      halt_reason,
      recon_ok ? "true" : "false",
      invariant_ok ? "true" : "false",
      cap_leg_a,
      cap_leg_b,
      cap_total_leg_a,
      cap_total_leg_b,
      peer_read_failed ? "true" : "false"
   );
}

#endif // GRIND_TELEMETRY_MQH
