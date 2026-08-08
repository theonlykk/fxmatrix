//+------------------------------------------------------------------+
//| fxmatrix_v2_state_reconstruction.mqh — Phase A pure SRE logic     |
//| Spec: docs/architecture/STATE_RECONSTRUCTION_SPEC_DRAFT.md (v8) |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_STATE_RECONSTRUCTION_MQH
#define FXMATRIX_V2_STATE_RECONSTRUCTION_MQH

#include "fxmatrix_v2_logic.mqh"
#include "fxmatrix_v2_exits.mqh"
#include "fxmatrix_v2_carry.mqh"

#define V2_SRE_COMMENT_L0     "V2_L0"
#define V2_SRE_COMMENT_ADD    "V2_Add"
#define V2_SRE_COMMENT_RELOAD "V2_Reload"
#define V2_SRE_COMMENT_EXIT   "V2_Exit"

#ifndef V2_SRE_DEFAULT_LOOKBACK_SEC
#define V2_SRE_DEFAULT_LOOKBACK_SEC (90 * 86400)
#endif

#define V2_SRE_CAP_GV_SENTINEL (-999999.0)

enum V2SREHaltReason
{
   V2_SRE_OK = 0,
   V2_SRE_HALT_01_EXIT_MAGIC_POSITION_OPEN,
   V2_SRE_HALT_02_EXIT_ORDER_ASSIGNMENT_AMBIGUOUS,
   V2_SRE_HALT_03_TOO_MANY_EXIT_ORDERS,
   V2_SRE_HALT_04_DANGLING_EXIT_ORDER,
   V2_SRE_HALT_05_MULTIPLE_ADD_RELOAD_PENDING,
   V2_SRE_HALT_06_PENDING_ENTRY_STACK_MISMATCH,
   V2_SRE_HALT_07_POSITION_TIME_ORDER_AMBIGUOUS,
   V2_SRE_HALT_08_POSITION_VOLUME_MISMATCH,
   V2_SRE_HALT_09_ANCHOR_NOT_FOUND,
   V2_SRE_HALT_10_UNMATCHED_HISTORICAL_DEAL,
   V2_SRE_HALT_11_PENDING_COMMENT_INCONSISTENT,
   V2_SRE_HALT_12_POSITION_TYPE_MISMATCH,
   V2_SRE_HALT_13_MULTIPLE_L0_PENDING,
   V2_SRE_HALT_14_EXIT_PRICE_NO_CANDIDATE,
   V2_SRE_HALT_15_MULTIPLE_ENTRY_IN_ONE_POSITION,
   V2_SRE_HALT_16_UNRESOLVED_HEDGE,
   V2_SRE_HALT_17_CLOSEBY_GROUP_SIZE,
   V2_SRE_HALT_18_HEDGE_ORDINARY_CLOSE,
   V2_SRE_HALT_19_MISSING_DEAL_ID,
   V2_SRE_HALT_20_PENDING_ENTRY_WRONG_DIRECTION,
   V2_SRE_HALT_21_UNMATCHED_EXIT_ORDER,
   V2_SRE_HALT_22_PENDING_ORDER_CLASS,
   V2_SRE_HALT_23_NON_STANDARD_ENTRY_CLOSE,
   V2_SRE_HALT_24_CLOSEBY_RESOLUTION,
   V2_SRE_HALT_27_ANCHOR_EXIT_MAGIC_REMNANT,
   V2_SRE_HALT_28_TIER1_NOT_UNIQUE,
   V2_SRE_HALT_29_TIER2_NOT_UNIQUE,
   V2_SRE_HALT_30_CLOSEBY_PRICE_INCONSISTENT,
   V2_SRE_HALT_VALIDATION_MISMATCH
};

struct V2SREPositionInput
{
   ulong    ticket;
   ulong    position_id;
   datetime open_time;
   double   entry_price;
   double   volume;
   int      direction;
   string   symbol;
   int      position_type;
};

struct V2SREExitOrderInput
{
   ulong    ticket;
   datetime placement_time;
   double   price;
   double   volume;
   int      direction;
   string   symbol;
};

struct V2SREPendingEntryInput
{
   ulong    ticket;
   datetime setup_time;
   double   price;
   double   volume;
   int      direction;
   string   symbol;
   string   comment;
   long     magic;
};

struct V2SREDealInput
{
   ulong    deal_ticket;
   ulong    position_id;
   ulong    order_id;
   datetime deal_time;
   long     entry_type;
   long     deal_type;
   long     deal_magic;
   long     deal_reason;
   double   price;
   double   volume;
   string   comment;
};

struct V2SREPositionTableEntry
{
   ulong    position_id;
   datetime open_time;
   double   open_price;
   double   volume;
};

struct V2SRECloseByPair
{
   ulong    entry_position_id;
   ulong    hedge_position_id;
   ulong    closeby_order_id;
   datetime hedge_open_time;
   double   hedge_open_price;
   double   entry_open_price;
};

struct V2SREPathState
{
   double current_add_pips;
   bool   last_exit_valid;
   double last_exit_price;
};

struct V2SRELayerSnapshot
{
   ulong    position_ticket;
   ulong    entry_ticket;
   double   entry_price;
   ulong    exit_ticket;
   double   exit_target;
   datetime entry_time;
};

struct V2SREMatchResult
{
   V2SREHaltReason halt;
   ulong             exit_tickets[];
   double            exit_targets[];
   bool              exit_rollover_tolerant[];
};

struct V2SREAnchorResult
{
   V2SREHaltReason halt;
   datetime        anchor_time;
   int             anchor_deal_index;
};

struct V2SREMapResult
{
   V2SREHaltReason  halt;
   V2SRECloseByPair pairs[];
};

struct V2SREReplayEvent
{
   datetime event_time;
   bool     is_removal;
   bool     is_reload;
   double   entry_price;
   ulong    entry_position_id;
};

struct V2SREAssignCtx
{
   int                 pc;
   int                 oc;
   bool                tier1_flat[];
   bool                tier2_flat[];
   V2SREPositionInput  positions[];
   V2SREExitOrderInput orders[];
   double              exit_pips;
   double              point;
   datetime            now;
   ulong               assign_ticket[];
   ulong               first_assign[];
   double              assign_target[];
   double              first_target[];
   bool                assign_rollover[];
   bool                first_rollover[];
   bool                found_valid;
   bool                search_abort;
   V2SREHaltReason     abort_reason;
};

//+------------------------------------------------------------------+
double V2_SRE_PipsToPrice(const double pips, const double point)
{
   if(point <= 0.0)
      return pips * 0.0001;
   return pips * point * 10.0;
}

double V2_SRE_ExpectedExitPrice(const double entry_price,
                                const int direction,
                                const double exit_pips,
                                const double point)
{
   const double delta = V2_SRE_PipsToPrice(exit_pips, point);
   return (direction > 0) ? entry_price + delta : entry_price - delta;
}

double V2_SRE_ExitPriceTolerance(const double point)
{
   return (point <= 0.0) ? 1e-5 : point * 0.5;
}

bool V2_SRE_PricesNear(const double a, const double b, const double tol)
{
   return (MathAbs(a - b) <= tol);
}

bool V2_SRE_ExitPriceMatchesFormula(const double order_price,
                                    const double entry_price,
                                    const int direction,
                                    const double exit_pips,
                                    const double point)
{
   const double expected = V2_SRE_ExpectedExitPrice(entry_price, direction, exit_pips, point);
   return V2_SRE_PricesNear(order_price, expected, V2_SRE_ExitPriceTolerance(point));
}

bool V2_SRE_HedgePriceConsistentWithEntry(const double hedge_open_price,
                                          const double entry_open_price,
                                          const int entry_direction,
                                          const double exit_pips,
                                          const double point)
{
   return V2_SRE_ExitPriceMatchesFormula(hedge_open_price, entry_open_price,
                                       entry_direction, exit_pips, point);
}

// Fixed per-instrument nominal spread (points, not pips) for HALT_30 fill-noise allowance.
// Compile-time constants only — NOT live/historical market data (ADR-108 / DeepSeek R2).
// Basis: typical FTMO demo spreads measured at Tier 1 fill times (Aug 2026 diagnostic);
// must cover observed 2–7pt execution-noise residuals on 0-midnight pairs.
double V2_SRE_NominalSpreadPoints(const string symbol)
{
   if(symbol == "EURUSD")
      return 10.0;   // ~1.0 pip typical
   if(symbol == "GBPUSD")
      return 15.0;   // ~1.5 pips typical
   if(symbol == "EURGBP")
      return 15.0;   // ~1.5 pips typical (wider cross)
   return 10.0;      // conservative default for unknown symbols
}

bool V2_SRE_HedgePriceIndicatesCrossPair(const double hedge_open_price,
                                         const double paired_entry_price,
                                         const int entry_direction,
                                         const double exit_pips,
                                         const double point,
                                         const datetime entry_open_time,
                                         const datetime hedge_open_time,
                                         const string symbol,
                                         const double add_pips_floor)
{
   const double expected = V2_SRE_ExpectedExitPrice(paired_entry_price, entry_direction,
                                                    exit_pips, point);
   const double max_shift = V2_SRE_MaxPossibleRolloverShift(entry_open_time, hedge_open_time,
                                                             symbol, entry_direction, point);
   const double expected_adj = V2_RolloverShiftedExitPrice(expected, max_shift, entry_direction);

   const double base_tol = V2_SRE_ExitPriceTolerance(point) * 4.0;
   const double grid_step = V2_SRE_PipsToPrice(add_pips_floor, point);
   const double margin = point;

   if(max_shift >= grid_step - base_tol - margin)
      return true;

   const int rollover_units = V2_SRE_CountRolloverMultiplierUnits(entry_open_time, hedge_open_time);
   const double noise_allowance = (rollover_units == 0)
                                  ? V2_SRE_NominalSpreadPoints(symbol) * point
                                  : 0.0;

   return (MathAbs(hedge_open_price - expected_adj) > base_tol + noise_allowance);
}

bool V2_SRE_CapGvIsBlocking(const bool gv_present, const double gv_value)
{
   if(!gv_present)
      return true;
   return V2_SRE_PricesNear(gv_value, V2_SRE_CAP_GV_SENTINEL, 1e-9);
}

bool V2_SRE_CapNetExposureBlocked(const bool &gv_present[], const double &gv_values[],
                                  const int count, double &net_out)
{
   net_out = 0.0;
   for(int i = 0; i < count; i++) {
      if(V2_SRE_CapGvIsBlocking(gv_present[i], gv_values[i]))
         return true;
      net_out += gv_values[i];
   }
   return false;
}

V2SREHaltReason V2_SRE_PreCheckExitMagicOpen(const V2SREPositionInput &exit_positions[])
{
   if(ArraySize(exit_positions) > 0)
      return V2_SRE_HALT_01_EXIT_MAGIC_POSITION_OPEN;
   return V2_SRE_OK;
}

bool V2_SRE_PositionTypeMatchesDirection(const int position_type, const int direction)
{
   if(direction > 0)
      return (position_type == POSITION_TYPE_BUY);
   if(direction < 0)
      return (position_type == POSITION_TYPE_SELL);
   return false;
}

void V2_SRE_SortPositionsByOpenTime(V2SREPositionInput &positions[])
{
   const int n = ArraySize(positions);
   for(int i = 0; i < n - 1; i++) {
      for(int j = i + 1; j < n; j++) {
         bool swap = false;
         if(positions[j].open_time < positions[i].open_time)
            swap = true;
         else if(positions[j].open_time == positions[i].open_time &&
                 positions[j].ticket < positions[i].ticket)
            swap = true;
         if(swap) {
            V2SREPositionInput tmp = positions[i];
            positions[i] = positions[j];
            positions[j] = tmp;
         }
      }
   }
}

void V2_SRE_SortDealsByTime(V2SREDealInput &deals[])
{
   const int n = ArraySize(deals);
   for(int i = 0; i < n - 1; i++) {
      for(int j = i + 1; j < n; j++) {
         if(deals[j].deal_time < deals[i].deal_time) {
            V2SREDealInput tmp = deals[i];
            deals[i] = deals[j];
            deals[j] = tmp;
         }
      }
   }
}

bool V2_SRE_Tier1BaseEligible(const V2SREPositionInput &pos,
                              const V2SREExitOrderInput &ord,
                              const datetime now,
                              const double expected_volume)
{
   if(pos.symbol != ord.symbol || pos.direction != ord.direction)
      return false;
   if(!V2_SRE_PricesNear(pos.volume, ord.volume, 1e-8))
      return false;
   if(!V2_SRE_PricesNear(pos.volume, expected_volume, 1e-8))
      return false;
   if(ord.placement_time < pos.open_time || ord.placement_time >= now)
      return false;
   return true;
}

bool V2_SRE_Tier1Eligible(const V2SREPositionInput &pos,
                          const V2SREExitOrderInput &ord,
                          const datetime now,
                          const double exit_pips,
                          const double point,
                          const double expected_volume)
{
   if(!V2_SRE_Tier1BaseEligible(pos, ord, now, expected_volume))
      return false;
   return V2_SRE_ExitPriceMatchesFormula(ord.price, pos.entry_price,
                                         pos.direction, exit_pips, point);
}

double V2_SRE_RolloverPriceTolerance(const double point)
{
   return V2_SRE_PipsToPrice(1.0, point) + V2_SRE_ExitPriceTolerance(point);
}

// Unit-test hook — disabled in production (g_v2_sre_test_swap_override=false).
bool   g_v2_sre_test_swap_override = false;
double g_v2_sre_test_swap_long     = 0.0;
double g_v2_sre_test_swap_short    = 0.0;

datetime V2_SRE_MidnightAtDayStart(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

int V2_SRE_CountRolloverMultiplierUnits(const datetime open_time, const datetime now)
{
   datetime first_midnight = V2_SRE_MidnightAtDayStart(open_time);
   if(open_time >= first_midnight)
      first_midnight += 86400;

   const datetime last_midnight = V2_SRE_MidnightAtDayStart(now);
   if(first_midnight > last_midnight)
      return 0;

   int total_units = 0;
   for(datetime cur = first_midnight; cur <= last_midnight; cur += 86400) {
      MqlDateTime cur_dt;
      TimeToStruct(cur, cur_dt);
      total_units += V2_RolloverWednesdayMultiplier(cur_dt.day_of_week);
   }
   return total_units;
}

double V2_SRE_QuerySwapForDirection(const string symbol, const int direction)
{
   if(g_v2_sre_test_swap_override)
      return (direction > 0) ? g_v2_sre_test_swap_long : g_v2_sre_test_swap_short;
   return (direction > 0) ? SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG)
                          : SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
}

double V2_SRE_MaxPossibleRolloverShift(const datetime open_time,
                                       const datetime now,
                                       const string symbol,
                                       const int direction,
                                       const double point)
{
   const int units = V2_SRE_CountRolloverMultiplierUnits(open_time, now);
   if(units <= 0)
      return 0.0;
   const double swap = V2_SRE_QuerySwapForDirection(symbol, direction);
   return V2_RolloverShiftPrice(swap, units, point);
}

bool V2_SRE_Tier2RolloverPriceInRange(const double order_price,
                                      const double expected,
                                      const double max_shift,
                                      const int direction)
{
   if(max_shift <= 0.0)
      return false;
   if(direction > 0)
      return (order_price >= expected && order_price <= expected + max_shift);
   return (order_price <= expected && order_price >= expected - max_shift);
}

bool V2_SRE_Tier2Eligible(const V2SREPositionInput &pos,
                          const V2SREExitOrderInput &ord,
                          const V2SREPositionInput &positions[],
                          const datetime now,
                          const double exit_pips,
                          const double point,
                          const double expected_volume)
{
   if(!V2_SRE_Tier1BaseEligible(pos, ord, now, expected_volume))
      return false;
   if(V2_SRE_ExitPriceMatchesFormula(ord.price, pos.entry_price,
                                     pos.direction, exit_pips, point))
      return false;
   for(int k = 0; k < ArraySize(positions); k++) {
      if(positions[k].position_id == pos.position_id)
         continue;
      if(V2_SRE_ExitPriceMatchesFormula(ord.price, positions[k].entry_price,
                                       positions[k].direction, exit_pips, point))
         return false;
   }
   const double expected = V2_SRE_ExpectedExitPrice(pos.entry_price, pos.direction,
                                                     exit_pips, point);
   const double max_shift = V2_SRE_MaxPossibleRolloverShift(pos.open_time, now,
                                                            pos.symbol, pos.direction,
                                                            point);
   return V2_SRE_Tier2RolloverPriceInRange(ord.price, expected, max_shift,
                                             pos.direction);
}

bool V2_SRE_AssignmentsEqual(const ulong &a[], const ulong &b[])
{
   if(ArraySize(a) != ArraySize(b))
      return false;
   for(int i = 0; i < ArraySize(a); i++)
      if(a[i] != b[i])
         return false;
   return true;
}

void V2_SRE_AssignRecurse(V2SREAssignCtx &ctx, const int depth, bool &used[])
{
   if(ctx.search_abort)
      return;

   if(depth >= ctx.pc) {
      for(int j = 0; j < ctx.oc; j++)
         if(!used[j])
            return;
      if(!ctx.found_valid) {
         for(int i = 0; i < ctx.pc; i++) {
            ctx.first_assign[i] = ctx.assign_ticket[i];
            ctx.first_target[i] = ctx.assign_target[i];
            ctx.first_rollover[i] = ctx.assign_rollover[i];
         }
         ctx.found_valid = true;
         return;
      }
      if(!V2_SRE_AssignmentsEqual(ctx.first_assign, ctx.assign_ticket)) {
         ctx.search_abort = true;
         ctx.abort_reason = V2_SRE_HALT_28_TIER1_NOT_UNIQUE;
      }
      return;
   }

   ctx.assign_ticket[depth] = 0;
   ctx.assign_target[depth] = V2_SRE_ExpectedExitPrice(ctx.positions[depth].entry_price,
                                                       ctx.positions[depth].direction,
                                                       ctx.exit_pips, ctx.point);
   ctx.assign_rollover[depth] = false;

   int tier1_opts[];
   ArrayResize(tier1_opts, 0);
   for(int j = 0; j < ctx.oc; j++) {
      if(ctx.tier1_flat[depth * ctx.oc + j] && !used[j]) {
         int n = ArraySize(tier1_opts);
         ArrayResize(tier1_opts, n + 1);
         tier1_opts[n] = j;
      }
   }

   for(int pass = 0; pass <= ArraySize(tier1_opts); pass++) {
      if(ctx.search_abort)
         return;

      bool used2[];
      ArrayResize(used2, ctx.oc);
      for(int j = 0; j < ctx.oc; j++)
         used2[j] = used[j];

      if(pass < ArraySize(tier1_opts)) {
         const int j = tier1_opts[pass];
         used2[j] = true;
         ctx.assign_ticket[depth] = ctx.orders[j].ticket;
         ctx.assign_target[depth] = ctx.orders[j].price;
         ctx.assign_rollover[depth] = false;
      } else {
         int tier2_count = 0;
         int tier2_j = -1;
         for(int j = 0; j < ctx.oc; j++) {
            if(used2[j])
               continue;
            if(ctx.tier2_flat[depth * ctx.oc + j]) {
               tier2_count++;
               tier2_j = j;
            }
         }
         if(tier2_count > 1) {
            // Mandatory tier-2 only (no tier-1 options): ambiguous → global halt.
            // Optional skip-tier-1 pass: dead branch only — do not abort a valid
            // tier-1 assignment found on an earlier pass.
            if(ArraySize(tier1_opts) == 0) {
               ctx.search_abort = true;
               ctx.abort_reason = V2_SRE_HALT_29_TIER2_NOT_UNIQUE;
            }
            return;
         }
         if(tier2_count == 1) {
            used2[tier2_j] = true;
            ctx.assign_ticket[depth] = ctx.orders[tier2_j].ticket;
            ctx.assign_target[depth] = ctx.orders[tier2_j].price;
            ctx.assign_rollover[depth] = true;
         }
      }
      V2_SRE_AssignRecurse(ctx, depth + 1, used2);
   }
}

V2SREMatchResult V2_SRE_MatchExitOrders(V2SREPositionInput &positions[],
                                        const V2SREExitOrderInput &orders[],
                                        const datetime now,
                                        const double exit_pips,
                                        const double point,
                                        const double expected_volume)
{
   V2SREMatchResult result;
   result.halt = V2_SRE_OK;
   ArrayResize(result.exit_tickets, 0);
   ArrayResize(result.exit_targets, 0);
   ArrayResize(result.exit_rollover_tolerant, 0);

   const int pc = ArraySize(positions);
   const int oc = ArraySize(orders);

   if(oc > pc) {
      result.halt = V2_SRE_HALT_03_TOO_MANY_EXIT_ORDERS;
      return result;
   }

   V2_SRE_SortPositionsByOpenTime(positions);

   if(oc == 0) {
      ArrayResize(result.exit_tickets, pc);
      ArrayResize(result.exit_targets, pc);
      ArrayResize(result.exit_rollover_tolerant, pc);
      for(int i = 0; i < pc; i++) {
         result.exit_tickets[i] = 0;
         result.exit_targets[i] = V2_SRE_ExpectedExitPrice(positions[i].entry_price,
                                                         positions[i].direction,
                                                         exit_pips, point);
         result.exit_rollover_tolerant[i] = false;
      }
      return result;
   }

   V2SREAssignCtx ctx;
   ctx.pc = pc;
   ctx.oc = oc;
   ctx.exit_pips = exit_pips;
   ctx.point = point;
   ctx.now = now;
   ctx.found_valid = false;
   ctx.search_abort = false;
   ctx.abort_reason = V2_SRE_OK;
   ArrayResize(ctx.positions, pc);
   ArrayResize(ctx.orders, oc);
   ArrayResize(ctx.tier1_flat, pc * oc);
   ArrayResize(ctx.tier2_flat, pc * oc);
   ArrayResize(ctx.assign_ticket, pc);
   ArrayResize(ctx.first_assign, pc);
   ArrayResize(ctx.assign_target, pc);
   ArrayResize(ctx.first_target, pc);
   ArrayResize(ctx.assign_rollover, pc);
   ArrayResize(ctx.first_rollover, pc);
   for(int i = 0; i < pc; i++) {
      ctx.positions[i] = positions[i];
      for(int j = 0; j < oc; j++) {
         ctx.tier1_flat[i * oc + j] = V2_SRE_Tier1Eligible(positions[i], orders[j], now,
                                                             exit_pips, point, expected_volume);
         ctx.tier2_flat[i * oc + j] = V2_SRE_Tier2Eligible(positions[i], orders[j], positions,
                                                             now, exit_pips, point, expected_volume);
      }
   }
   for(int j = 0; j < oc; j++)
      ctx.orders[j] = orders[j];

   bool used0[];
   ArrayResize(used0, oc);
   for(int j = 0; j < oc; j++)
      used0[j] = false;
   V2_SRE_AssignRecurse(ctx, 0, used0);

   if(ctx.search_abort) {
      result.halt = ctx.abort_reason;
      return result;
   }
   if(!ctx.found_valid) {
      result.halt = V2_SRE_HALT_21_UNMATCHED_EXIT_ORDER;
      return result;
   }

   ArrayResize(result.exit_tickets, pc);
   ArrayResize(result.exit_targets, pc);
   ArrayResize(result.exit_rollover_tolerant, pc);
   for(int i = 0; i < pc; i++) {
      result.exit_tickets[i] = ctx.first_assign[i];
      result.exit_targets[i] = ctx.first_target[i];
      result.exit_rollover_tolerant[i] = ctx.first_rollover[i];
   }
   return result;
}

bool V2_SRE_IsEntryPositionId(const ulong position_id,
                              const V2SREDealInput &deals[],
                              const long entry_magic)
{
   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].position_id != position_id)
         continue;
      if(deals[i].entry_type == DEAL_ENTRY_IN && deals[i].deal_magic == entry_magic)
         return true;
   }
   return false;
}

bool V2_SRE_IsExitPositionId(const ulong position_id,
                             const V2SREDealInput &deals[],
                             const long exit_magic)
{
   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].position_id != position_id)
         continue;
      if(deals[i].entry_type == DEAL_ENTRY_IN && deals[i].deal_magic == exit_magic)
         return true;
   }
   return false;
}

double V2_SRE_PositionNetVolume(const ulong position_id,
                                const V2SREDealInput &deals[],
                                const int deal_index,
                                const long entry_magic,
                                const long exit_magic)
{
   const bool is_entry = V2_SRE_IsEntryPositionId(position_id, deals, entry_magic);
   const bool is_exit = V2_SRE_IsExitPositionId(position_id, deals, exit_magic);
   if(!is_entry && !is_exit)
      return 0.0;

   double vol = 0.0;
   for(int i = 0; i <= deal_index; i++) {
      if(deals[i].position_id != position_id)
         continue;
      if(deals[i].entry_type == DEAL_ENTRY_IN)
         vol += deals[i].volume;
      else if(deals[i].entry_type == DEAL_ENTRY_OUT ||
              deals[i].entry_type == DEAL_ENTRY_OUT_BY)
         vol -= deals[i].volume;
   }
   return vol;
}

void V2_SRE_CollectManagedPositionIds(const V2SREDealInput &deals[],
                                      const int deal_index,
                                      const long entry_magic,
                                      const long exit_magic,
                                      const bool want_entry,
                                      ulong &ids[])
{
   ArrayResize(ids, 0);
   for(int i = 0; i <= deal_index; i++) {
      const ulong pid = deals[i].position_id;
      if(pid == 0)
         continue;
      bool known = false;
      for(int k = 0; k < ArraySize(ids); k++) {
         if(ids[k] == pid) {
            known = true;
            break;
         }
      }
      if(known)
         continue;
      if(want_entry && V2_SRE_IsEntryPositionId(pid, deals, entry_magic)) {
         int n = ArraySize(ids);
         ArrayResize(ids, n + 1);
         ids[n] = pid;
      } else if(!want_entry && V2_SRE_IsExitPositionId(pid, deals, exit_magic)) {
         int n = ArraySize(ids);
         ArrayResize(ids, n + 1);
         ids[n] = pid;
      }
   }
}

double V2_SRE_TotalManagedVolume(const V2SREDealInput &deals[],
                                 const int deal_index,
                                 const long entry_magic,
                                 const long exit_magic,
                                 const bool count_entry)
{
   ulong ids[];
   V2_SRE_CollectManagedPositionIds(deals, deal_index, entry_magic, exit_magic,
                                      count_entry, ids);
   double total = 0.0;
   for(int i = 0; i < ArraySize(ids); i++)
      total += V2_SRE_PositionNetVolume(ids[i], deals, deal_index, entry_magic, exit_magic);
   return total;
}

V2SREAnchorResult V2_SRE_FindAnchor(V2SREDealInput &deals[],
                                    const datetime lookback_from,
                                    const int lookback_sec,
                                    const long entry_magic,
                                    const long exit_magic)
{
   V2SREAnchorResult result;
   result.halt = V2_SRE_OK;
   result.anchor_time = 0;
   result.anchor_deal_index = -1;

   V2SREDealInput window[];
   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].deal_time < lookback_from - lookback_sec)
         continue;
      if(deals[i].deal_time > lookback_from)
         continue;
      int n = ArraySize(window);
      ArrayResize(window, n + 1);
      window[n] = deals[i];
   }
   if(ArraySize(window) == 0) {
      result.halt = V2_SRE_HALT_09_ANCHOR_NOT_FOUND;
      return result;
   }

   V2_SRE_SortDealsByTime(window);
   int last_flat = -1;
   for(int i = 0; i < ArraySize(window); ) {
      const datetime bucket_time = window[i].deal_time;
      int last_in_bucket = i;
      while(last_in_bucket + 1 < ArraySize(window) &&
            window[last_in_bucket + 1].deal_time == bucket_time)
         last_in_bucket++;
      const double entry_vol = V2_SRE_TotalManagedVolume(window, last_in_bucket,
                                                          entry_magic, exit_magic, true);
      const double exit_vol = V2_SRE_TotalManagedVolume(window, last_in_bucket,
                                                        entry_magic, exit_magic, false);
      if(entry_vol <= 1e-12 && exit_vol > 1e-12) {
         result.halt = V2_SRE_HALT_27_ANCHOR_EXIT_MAGIC_REMNANT;
         return result;
      }
      if(entry_vol <= 1e-12 && exit_vol <= 1e-12)
         last_flat = last_in_bucket;
      i = last_in_bucket + 1;
   }

   if(last_flat < 0) {
      result.halt = V2_SRE_HALT_09_ANCHOR_NOT_FOUND;
      return result;
   }

   result.anchor_time = window[last_flat].deal_time;
   result.anchor_deal_index = last_flat;
   return result;
}

double V2_SRE_EntryVolumeAtAnchorWalk(const V2SREDealInput &deals[],
                                      const int deal_index,
                                      const long entry_magic,
                                      const long exit_magic)
{
   return V2_SRE_TotalManagedVolume(deals, deal_index, entry_magic, exit_magic, true);
}

void V2_SRE_BuildPositionTablesFromDeals(const V2SREDealInput &deals[],
                                         const datetime anchor_time,
                                         const long entry_magic,
                                         const long exit_magic,
                                         V2SREPositionTableEntry &entry_table[],
                                         V2SREPositionTableEntry &hedge_table[])
{
   ArrayResize(entry_table, 0);
   ArrayResize(hedge_table, 0);
   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].deal_time <= anchor_time)
         continue;
      if(deals[i].entry_type != DEAL_ENTRY_IN || deals[i].position_id == 0)
         continue;

      V2SREPositionTableEntry row;
      row.position_id = deals[i].position_id;
      row.open_time = deals[i].deal_time;
      row.open_price = deals[i].price;
      row.volume = deals[i].volume;

      if(deals[i].deal_magic == entry_magic) {
         int n = ArraySize(entry_table);
         ArrayResize(entry_table, n + 1);
         entry_table[n] = row;
      } else if(deals[i].deal_magic == exit_magic) {
         int n = ArraySize(hedge_table);
         ArrayResize(hedge_table, n + 1);
         hedge_table[n] = row;
      }
   }
}

int V2_SRE_FindTableIndexByPositionId(const V2SREPositionTableEntry &table[],
                                      const ulong position_id)
{
   for(int i = 0; i < ArraySize(table); i++)
      if(table[i].position_id == position_id)
         return i;
   return -1;
}

V2SREMapResult V2_SRE_MapHedgeToEntry(const V2SREDealInput &deals[],
                                      const datetime anchor_time,
                                      const long entry_magic,
                                      const long exit_magic,
                                      const int entry_direction,
                                      const double exit_pips,
                                      const double point,
                                      const string symbol,
                                      const double add_pips_floor)
{
   V2SREMapResult result;
   result.halt = V2_SRE_OK;
   ArrayResize(result.pairs, 0);

   V2SREPositionTableEntry entry_table[];
   V2SREPositionTableEntry hedge_table[];
   V2_SRE_BuildPositionTablesFromDeals(deals, anchor_time, entry_magic, exit_magic,
                                       entry_table, hedge_table);

   ulong order_groups[];
   int group_sizes[];
   ArrayResize(order_groups, 0);

   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].deal_time <= anchor_time)
         continue;
      if(deals[i].entry_type != DEAL_ENTRY_OUT_BY)
         continue;
      if(deals[i].order_id == 0 || deals[i].position_id == 0) {
         result.halt = V2_SRE_HALT_19_MISSING_DEAL_ID;
         return result;
      }
      int gi = -1;
      for(int g = 0; g < ArraySize(order_groups); g++) {
         if(order_groups[g] == deals[i].order_id) {
            gi = g;
            break;
         }
      }
      if(gi < 0) {
         gi = ArraySize(order_groups);
         ArrayResize(order_groups, gi + 1);
         ArrayResize(group_sizes, gi + 1);
         order_groups[gi] = deals[i].order_id;
         group_sizes[gi] = 0;
      }
      group_sizes[gi]++;
   }

   for(int g = 0; g < ArraySize(order_groups); g++) {
      if(group_sizes[g] != 2) {
         result.halt = V2_SRE_HALT_17_CLOSEBY_GROUP_SIZE;
         return result;
      }
   }

   for(int g = 0; g < ArraySize(order_groups); g++) {
      ulong pids[];
      ArrayResize(pids, 0);
      for(int i = 0; i < ArraySize(deals); i++) {
         if(deals[i].deal_time <= anchor_time)
            continue;
         if(deals[i].entry_type != DEAL_ENTRY_OUT_BY)
            continue;
         if(deals[i].order_id != order_groups[g])
            continue;
         int n = ArraySize(pids);
         ArrayResize(pids, n + 1);
         pids[n] = deals[i].position_id;
      }

      int entry_idx = -1;
      int hedge_idx = -1;
      for(int k = 0; k < ArraySize(pids); k++) {
         if(V2_SRE_FindTableIndexByPositionId(entry_table, pids[k]) >= 0)
            entry_idx = k;
         if(V2_SRE_FindTableIndexByPositionId(hedge_table, pids[k]) >= 0)
            hedge_idx = k;
      }
      if(entry_idx < 0 || hedge_idx < 0 || entry_idx == hedge_idx) {
         result.halt = V2_SRE_HALT_24_CLOSEBY_RESOLUTION;
         return result;
      }

      const int et = V2_SRE_FindTableIndexByPositionId(entry_table, pids[entry_idx]);
      const int ht = V2_SRE_FindTableIndexByPositionId(hedge_table, pids[hedge_idx]);
      if(V2_SRE_HedgePriceIndicatesCrossPair(hedge_table[ht].open_price,
                                             entry_table[et].open_price,
                                             entry_direction, exit_pips, point,
                                             entry_table[et].open_time,
                                             hedge_table[ht].open_time,
                                             symbol,
                                             add_pips_floor)) {
         result.halt = V2_SRE_HALT_30_CLOSEBY_PRICE_INCONSISTENT;
         return result;
      }

      V2SRECloseByPair pair;
      pair.entry_position_id = entry_table[et].position_id;
      pair.hedge_position_id = hedge_table[ht].position_id;
      pair.closeby_order_id = order_groups[g];
      pair.hedge_open_time = hedge_table[ht].open_time;
      pair.hedge_open_price = hedge_table[ht].open_price;
      pair.entry_open_price = entry_table[et].open_price;
      int n = ArraySize(result.pairs);
      ArrayResize(result.pairs, n + 1);
      result.pairs[n] = pair;
   }

   for(int h = 0; h < ArraySize(hedge_table); h++) {
      bool paired = false;
      for(int p = 0; p < ArraySize(result.pairs); p++) {
         if(result.pairs[p].hedge_position_id == hedge_table[h].position_id) {
            paired = true;
            break;
         }
      }
      if(!paired) {
         result.halt = V2_SRE_HALT_16_UNRESOLVED_HEDGE;
         return result;
      }
   }

   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].deal_time <= anchor_time)
         continue;
      if(deals[i].entry_type != DEAL_ENTRY_OUT)
         continue;
      if(!V2_SRE_IsExitPositionId(deals[i].position_id, deals, exit_magic))
         continue;
      for(int p = 0; p < ArraySize(result.pairs); p++) {
         if(result.pairs[p].hedge_position_id != deals[i].position_id)
            continue;
         const double entry_vol = V2_SRE_PositionNetVolume(result.pairs[p].entry_position_id,
                                                           deals, ArraySize(deals) - 1,
                                                           entry_magic, exit_magic);
         if(entry_vol > 1e-12) {
            result.halt = V2_SRE_HALT_18_HEDGE_ORDINARY_CLOSE;
            return result;
         }
      }
   }

   return result;
}

V2SREHaltReason V2_SRE_CheckNonStandardClosures(const V2SREDealInput &deals[],
                                                  const datetime lookback_from,
                                                  const int lookback_sec,
                                                  const long entry_magic)
{
   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].deal_time < lookback_from - lookback_sec)
         continue;
      if(deals[i].position_id == 0)
         continue;
      if(!V2_SRE_IsEntryPositionId(deals[i].position_id, deals, entry_magic))
         continue;
      if(deals[i].entry_type == DEAL_ENTRY_OUT_BY)
         continue;
      if(deals[i].entry_type == DEAL_ENTRY_OUT || deals[i].deal_reason == DEAL_REASON_SO)
         return V2_SRE_HALT_23_NON_STANDARD_ENTRY_CLOSE;
   }
   return V2_SRE_OK;
}

void V2_SRE_BuildReplayEvents(const V2SREDealInput &deals[],
                              const datetime anchor_time,
                              const long entry_magic,
                              const V2SRECloseByPair &pairs[],
                              V2SREReplayEvent &events[])
{
   ArrayResize(events, 0);
   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].deal_time <= anchor_time)
         continue;
      if(deals[i].entry_type != DEAL_ENTRY_IN)
         continue;
      if(deals[i].deal_magic != entry_magic)
         continue;

      V2SREReplayEvent ev;
      ev.event_time = deals[i].deal_time;
      ev.is_removal = false;
      ev.is_reload = (deals[i].comment == V2_SRE_COMMENT_RELOAD);
      ev.entry_price = deals[i].price;
      ev.entry_position_id = deals[i].position_id;
      int n = ArraySize(events);
      ArrayResize(events, n + 1);
      events[n] = ev;
   }

   for(int p = 0; p < ArraySize(pairs); p++) {
      V2SREReplayEvent ev;
      ev.event_time = pairs[p].hedge_open_time;
      ev.is_removal = true;
      ev.is_reload = false;
      ev.entry_price = pairs[p].entry_open_price;
      ev.entry_position_id = pairs[p].entry_position_id;
      int n = ArraySize(events);
      ArrayResize(events, n + 1);
      events[n] = ev;
   }

   for(int i = 0; i < ArraySize(events) - 1; i++) {
      for(int j = i + 1; j < ArraySize(events); j++) {
         bool swap = false;
         if(events[j].event_time < events[i].event_time)
            swap = true;
         else if(events[j].event_time == events[i].event_time &&
                 events[j].is_removal && !events[i].is_removal)
            swap = true;
         if(swap) {
            V2SREReplayEvent tmp = events[i];
            events[i] = events[j];
            events[j] = tmp;
         }
      }
   }
}

int V2_SRE_FindStackIndex(const double &stack[], const double entry_price)
{
   for(int i = 0; i < ArraySize(stack); i++) {
      if(V2_SRE_PricesNear(stack[i], entry_price, 1e-9))
         return i;
   }
   return -1;
}

void V2_SRE_RemoveStackAt(double &stack[], const int idx)
{
   const int n = ArraySize(stack);
   if(idx < 0 || idx >= n)
      return;
   for(int i = idx; i < n - 1; i++)
      stack[i] = stack[i + 1];
   ArrayResize(stack, n - 1);
}

V2SREPathState V2_SRE_ReplayPathDependentState(const V2SREReplayEvent &events[],
                                               const double add_pips_floor,
                                               const double widen_ratio,
                                               const double add_pips_ceiling)
{
   V2SREPathState state;
   state.current_add_pips = add_pips_floor;
   state.last_exit_valid = false;
   state.last_exit_price = 0.0;

   double stack[];
   ArrayResize(stack, 0);

   for(int i = 0; i < ArraySize(events); i++) {
      if(events[i].is_removal) {
         const int n = ArraySize(stack);
         const int idx = V2_SRE_FindStackIndex(stack, events[i].entry_price);
         if(idx < 0)
            continue;
         const bool was_top = (idx == n - 1);
         if(was_top) {
            state.last_exit_price = events[i].entry_price;
            state.last_exit_valid = true;
         } else {
            state.last_exit_valid = false;
         }
         V2_SRE_RemoveStackAt(stack, idx);
         if(ArraySize(stack) == 0)
            state.current_add_pips = add_pips_floor;
         continue;
      }

      const int n = ArraySize(stack);
      ArrayResize(stack, n + 1);
      stack[n] = events[i].entry_price;
      if(events[i].is_reload)
         state.last_exit_valid = false;
      if(ArraySize(stack) >= 3)
         state.current_add_pips = MathMin(add_pips_ceiling, state.current_add_pips * widen_ratio);
   }
   return state;
}

V2SREHaltReason V2_SRE_CheckPendingEntryConsistency(const V2SREPendingEntryInput &pending[],
                                                      const int stack_depth,
                                                      const int side_direction)
{
   int l0_count = 0;
   int add_reload_count = 0;
   for(int i = 0; i < ArraySize(pending); i++) {
      if(pending[i].direction != side_direction)
         return V2_SRE_HALT_20_PENDING_ENTRY_WRONG_DIRECTION;
      if(pending[i].comment == V2_SRE_COMMENT_L0)
         l0_count++;
      else if(pending[i].comment == V2_SRE_COMMENT_ADD ||
              pending[i].comment == V2_SRE_COMMENT_RELOAD)
         add_reload_count++;
      else
         return V2_SRE_HALT_11_PENDING_COMMENT_INCONSISTENT;
   }

   if(stack_depth == 0) {
      if(l0_count > 1)
         return V2_SRE_HALT_13_MULTIPLE_L0_PENDING;
      if(add_reload_count > 0)
         return V2_SRE_HALT_06_PENDING_ENTRY_STACK_MISMATCH;
   } else {
      if(l0_count > 0)
         return V2_SRE_HALT_06_PENDING_ENTRY_STACK_MISMATCH;
      if(add_reload_count > 1)
         return V2_SRE_HALT_05_MULTIPLE_ADD_RELOAD_PENDING;
   }
   return V2_SRE_OK;
}

bool V2_SRE_CheckOpenPositionTypes(const V2SREPositionInput &positions[],
                                   const int side_direction)
{
   for(int i = 0; i < ArraySize(positions); i++) {
      if(!V2_SRE_PositionTypeMatchesDirection(positions[i].position_type, side_direction))
         return false;
   }
   return true;
}

bool V2_SRE_CheckPositionVolumes(const V2SREPositionInput &positions[],
                                 const double expected_volume)
{
   for(int i = 0; i < ArraySize(positions); i++) {
      if(!V2_SRE_PricesNear(positions[i].volume, expected_volume, 1e-8))
         return false;
   }
   return true;
}

bool V2_SRE_CheckEntryInDealCount(const ulong position_id,
                                  const V2SREDealInput &deals[],
                                  const long entry_magic)
{
   int count = 0;
   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].position_id != position_id)
         continue;
      if(deals[i].entry_type != DEAL_ENTRY_IN)
         continue;
      if(deals[i].deal_magic != entry_magic)
         continue;
      count++;
   }
   return (count <= 1);
}

V2SREHaltReason V2_SRE_CheckMultipleEntryInDeals(const V2SREDealInput &deals[],
                                                 const long entry_magic)
{
   ulong seen[];
   ArrayResize(seen, 0);
   for(int i = 0; i < ArraySize(deals); i++) {
      if(deals[i].entry_type != DEAL_ENTRY_IN || deals[i].deal_magic != entry_magic)
         continue;
      if(deals[i].position_id == 0)
         continue;
      if(!V2_SRE_CheckEntryInDealCount(deals[i].position_id, deals, entry_magic))
         return V2_SRE_HALT_15_MULTIPLE_ENTRY_IN_ONE_POSITION;
   }
   return V2_SRE_OK;
}

V2SREHaltReason V2_SRE_CheckAmbiguity(const V2SREHaltReason precheck,
                                      const V2SREMatchResult &match,
                                      const V2SREAnchorResult &anchor,
                                      const V2SREMapResult &map_result,
                                      const V2SREHaltReason nonstd_halt,
                                      const bool position_types_ok,
                                      const bool volumes_ok,
                                      const V2SREHaltReason pending_halt,
                                      const V2SREHaltReason entry_in_halt)
{
   if(precheck != V2_SRE_OK)
      return precheck;
   if(!position_types_ok)
      return V2_SRE_HALT_12_POSITION_TYPE_MISMATCH;
   if(!volumes_ok)
      return V2_SRE_HALT_08_POSITION_VOLUME_MISMATCH;
   if(pending_halt != V2_SRE_OK)
      return pending_halt;
   if(entry_in_halt != V2_SRE_OK)
      return entry_in_halt;
   if(match.halt != V2_SRE_OK)
      return match.halt;
   if(anchor.halt != V2_SRE_OK)
      return anchor.halt;
   if(map_result.halt != V2_SRE_OK)
      return map_result.halt;
   if(nonstd_halt != V2_SRE_OK)
      return nonstd_halt;
   return V2_SRE_OK;
}

// §5 — validates layer count/tickets/entry prices only.
// Does NOT validate last_exit_valid or current_add_pips: no independent
// broker source exists for those path-dependent values (spec §5).
V2SREHaltReason V2_SRE_ValidateReconstruction(const V2SRELayerSnapshot &reconstructed[],
                                              const V2SRELayerSnapshot &broker_read[])
{
   if(ArraySize(reconstructed) != ArraySize(broker_read))
      return V2_SRE_HALT_VALIDATION_MISMATCH;
   for(int i = 0; i < ArraySize(reconstructed); i++) {
      if(reconstructed[i].position_ticket != broker_read[i].position_ticket)
         return V2_SRE_HALT_VALIDATION_MISMATCH;
      if(reconstructed[i].entry_ticket != broker_read[i].entry_ticket)
         return V2_SRE_HALT_VALIDATION_MISMATCH;
      if(reconstructed[i].entry_price != broker_read[i].entry_price)
         return V2_SRE_HALT_VALIDATION_MISMATCH;
   }
   return V2_SRE_OK;
}

void V2_SRE_BuildLayerSnapshotsFromPositions(const V2SREPositionInput &positions[],
                                             const V2SREMatchResult &match,
                                             V2SRELayerSnapshot &layers[])
{
   const int n = ArraySize(positions);
   ArrayResize(layers, n);
   for(int i = 0; i < n; i++) {
      layers[i].position_ticket = positions[i].position_id;
      layers[i].entry_ticket = positions[i].ticket;
      layers[i].entry_price = positions[i].entry_price;
      layers[i].entry_time = positions[i].open_time;
      if(i < ArraySize(match.exit_tickets))
         layers[i].exit_ticket = match.exit_tickets[i];
      else
         layers[i].exit_ticket = 0;
      if(i < ArraySize(match.exit_targets))
         layers[i].exit_target = match.exit_targets[i];
      else
         layers[i].exit_target = 0.0;
   }
}

#endif // FXMATRIX_V2_STATE_RECONSTRUCTION_MQH
