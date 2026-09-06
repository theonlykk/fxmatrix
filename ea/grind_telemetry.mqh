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
                                    const bool peer_read_failed,
                                    const ulong magic,
                                    const string slot,
                                    const double width_pips,
                                    const double add_pips,
                                    const double exit_pips,
                                    const int max_layers,
                                    const string cap_leg_a_name,
                                    const string cap_leg_b_name)
{
   return StringFormat(
      "{\"instance\":\"%s\",\"open_layers_long\":%d,\"open_layers_short\":%d,"
      "\"fills\":%d,\"scalps\":%d,\"api_count\":%d,\"api_counter_broken\":%s,"
      "\"cap_blocked\":%s,\"halted\":%s,\"halt_reason\":\"%s\","
      "\"recon_ok\":%s,\"invariant_ok\":%s,\"cap_leg_a\":%.4f,\"cap_leg_b\":%.4f,"
      "\"cap_total_leg_a\":%.4f,\"cap_total_leg_b\":%.4f,"
      "\"peer_read_failed\":%s,"
      "\"magic\":%s,\"slot\":\"%s\",\"width_pips\":%.4f,\"add_pips\":%.4f,"
      "\"exit_pips\":%.4f,\"max_layers\":%d,"
      "\"cap_leg_a_name\":\"%s\",\"cap_leg_b_name\":\"%s\"}",
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
      peer_read_failed ? "true" : "false",
      IntegerToString((long)magic),
      slot,
      width_pips,
      add_pips,
      exit_pips,
      max_layers,
      cap_leg_a_name,
      cap_leg_b_name
   );
}

#endif // GRIND_TELEMETRY_MQH
