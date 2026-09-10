//+------------------------------------------------------------------+
//| grind_telemetry.mqh — per-instance heartbeat for pipshed         |
//+------------------------------------------------------------------+
#ifndef GRIND_TELEMETRY_MQH
#define GRIND_TELEMETRY_MQH

#include "grind_api_counter.mqh"
#include "grind_pnl.mqh"
#include "grind_recon_failure.mqh"

// Unit-test hook: intercept WebRequest when active (fxgrind_tests).
bool   g_grind_telemetry_test_active = false;
int    g_grind_telemetry_test_post_calls = 0;
string g_grind_telemetry_test_last_url = "";
string g_grind_telemetry_test_last_payload = "";
bool   g_grind_telemetry_test_force_fail = false;

// Forward declarations — defined in grind_heartbeat_detail.mqh (included at end of grind_engine).
string Grind_HeartbeatBuildLayerDetailJson(const ulong magic, const int digits);
void Grind_HeartbeatMeasureWorstCasePayload(const int max_layers_cap,
                                            const int digits,
                                            const ulong magic,
                                            int &detail_chars_out,
                                            int &full_chars_out,
                                            string &detail_json_out,
                                            string &full_json_out);

void Grind_HeartbeatJournalSplitLineLengths(const string instance_name,
                                            const string full_json,
                                            int &unsplit_line_chars_out,
                                            int &scalar_line_chars_out,
                                            int &detail_line_chars_out,
                                            bool &split_would_fire_out);

//+------------------------------------------------------------------+
void Grind_TelemetryTestReset()
{
   g_grind_telemetry_test_active = false;
   g_grind_telemetry_test_post_calls = 0;
   g_grind_telemetry_test_last_url = "";
   g_grind_telemetry_test_last_payload = "";
   g_grind_telemetry_test_force_fail = false;
}

//+------------------------------------------------------------------+
bool Grind_TelemetryWebPost(const string url,
                            const string api_key,
                            const string payload,
                            const bool verbose_log)
{
   if(url == "" || api_key == "")
      return false;

   if(g_grind_telemetry_test_active) {
      g_grind_telemetry_test_post_calls++;
      g_grind_telemetry_test_last_url = url;
      g_grind_telemetry_test_last_payload = payload;
      return !g_grind_telemetry_test_force_fail;
   }

   string headers = "Content-Type: application/json\r\n"
                  + "Authorization: Bearer " + api_key + "\r\n";

   char post_data[];
   char result_data[];
   string result_headers;
   StringToCharArray(payload, post_data, 0, StringLen(payload));

   int http_status = WebRequest(
      "POST",
      url,
      headers,
      200,
      post_data,
      result_data,
      result_headers
   );

   if(verbose_log) {
      if(http_status == 200)
         Print("INFO: grind telemetry POST ok url=", url);
      else if(http_status == -1)
         Print("INFO: grind telemetry dropped status=-1 url=", url,
               " — add URL to Tools > Options > Expert Advisors allow list");
      else
         Print("INFO: grind telemetry dropped status=", http_status, " url=", url);
   }

   return (http_status == 200);
}

//+------------------------------------------------------------------+
void Grind_TelemetryEmit(const string instance_name,
                         const string event,
                         const string detail_json = "{}")
{
   Print("TELEM|", instance_name, "|", event, "|", detail_json);
}

//+------------------------------------------------------------------+
void Grind_TelemetryEmitHeartbeat(const string instance_name,
                                  const string full_json)
{
   const string prefix = "TELEM|" + instance_name + "|HEARTBEAT|";
   const int line_len = StringLen(prefix) + StringLen(full_json);

   if(line_len >= 4096) {
      const int layers_pos = StringFind(full_json, ",\"layers\":");
      if(layers_pos >= 0) {
         const string scalar_json = StringSubstr(full_json, 0, layers_pos) + "}";
         const string detail_json = "{" + StringSubstr(full_json, layers_pos + 1);
         Print(prefix, scalar_json);
         Print("TELEM|", instance_name, "|HEARTBEAT_DETAIL|", detail_json);
         return;
      }
   }

   Print(prefix, full_json);
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
   Grind_ResetDailyPnlIfNewDay();
   const double net_mtm = Grind_ComputeNetFloatingMtm(magic);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   const string core = StringFormat(
      "{\"instance_id\":\"%s\",\"open_layers_long\":%d,\"open_layers_short\":%d,"
      "\"fills\":%d,\"scalps\":%d,\"api_count\":%d,\"api_counter_broken\":%s,"
      "\"cap_blocked\":%s,\"halted\":%s,\"halt_reason\":\"%s\","
      "\"recon_ok\":%s,\"invariant_ok\":%s,\"recon_failure\":%s,\"cap_leg_a\":%.4f,\"cap_leg_b\":%.4f,"
      "\"cap_total_leg_a\":%.4f,\"cap_total_leg_b\":%.4f,"
      "\"peer_read_failed\":%s,"
      "\"magic\":%s,\"slot\":\"%s\",\"width_pips\":%.4f,\"add_pips\":%.4f,"
      "\"exit_pips\":%.4f,\"max_layers\":%d,"
      "\"cap_leg_a_name\":\"%s\",\"cap_leg_b_name\":\"%s\","
      "\"net_mtm\":%.4f,\"realised_pnl_today\":%.4f,\"scalp_pnl_last\":%.4f,"
      "\"exit_penetration_pips_last\":%.4f,\"exit_penetration_pips_mean\":%.4f,"
      "\"exit_touch_revert_count\":%d",
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
      Grind_ReconFailureHeartbeatField(),
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
      cap_leg_b_name,
      net_mtm,
      g_grind_realised_pnl_today,
      g_grind_scalp_pnl_last,
      g_grind_exit_penetration_pips_last,
      Grind_ExitPenetrationPipsMean(),
      g_grind_exit_touch_revert_count
   );

   const string detail = Grind_HeartbeatBuildLayerDetailJson(magic, digits);
   return core + "," + detail + "}";
}

#include "grind_scalp_events.mqh"

#endif // GRIND_TELEMETRY_MQH
