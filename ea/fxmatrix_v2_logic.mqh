//+------------------------------------------------------------------+
//| fxmatrix_v2_logic.mqh — shared V2 geometry + state helpers        |
//| Used by fxmatrix_v2.mq5 and fxmatrix_v2_tests.mq5                 |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_LOGIC_MQH
#define FXMATRIX_V2_LOGIC_MQH

#define MM_LONG_V2   20260901
#define MM_SHORT_V2  20260902

#define V2_ADD_PIPS_FLOOR    9.0
#define V2_WIDEN_RATIO       1.304
#define V2_ADD_PIPS_CEILING  1000.0
#define V2_EXIT_PIPS         3.0

//+------------------------------------------------------------------+
//| Positional closed-form (NOT used in production — reference only). |
//+------------------------------------------------------------------+
double V2_SpacingPipsDn_Positional(const int n)
{
   if(n <= 2)
      return V2_ADD_PIPS_FLOOR;
   double raw = V2_ADD_PIPS_FLOOR * MathPow(V2_WIDEN_RATIO, n - 2);
   return MathMin(V2_ADD_PIPS_CEILING, raw);
}

//+------------------------------------------------------------------+
//| Validated running-state add spacing (depth_before = stack size).  |
//| Floor 9 pips while depth_before < 3; else accumulated state.      |
//+------------------------------------------------------------------+
double V2_AddStepPipsForDepth(const int depth_before, const double current_add_pips)
{
   if(depth_before < 3)
      return V2_ADD_PIPS_FLOOR;
   return current_add_pips;
}

//+------------------------------------------------------------------+
//| Advance widen state after append when resulting depth >= 3.         |
//| Matches validated test-stage: any append (add or reload).         |
//+------------------------------------------------------------------+
void V2_AdvanceAddPipsOnAppend(double &current_add_pips, const int depth_after)
{
   if(depth_after >= 3)
      current_add_pips = MathMin(V2_ADD_PIPS_CEILING, current_add_pips * V2_WIDEN_RATIO);
}

//+------------------------------------------------------------------+
//| Reset widen state when instance stack returns fully flat.         |
//+------------------------------------------------------------------+
void V2_ResetAddPipsOnFlat(double &current_add_pips, const int layer_count)
{
   if(layer_count == 0)
      current_add_pips = V2_ADD_PIPS_FLOOR;
}

//+------------------------------------------------------------------+
//| After PopTopLayer: reset reload gate only when THIS instance's     |
//| internal stack is empty. Never consult account PositionsTotal().  |
//+------------------------------------------------------------------+
void V2_OnOwnStackFlat(bool &last_exit_valid, const int layer_count)
{
   if(layer_count == 0)
      last_exit_valid = false;
}

//+------------------------------------------------------------------+
//| Build ticket-targeted SLTP modify for LIFO exit (position close).  |
//+------------------------------------------------------------------+
bool V2_BuildExitSltpRequest(const string symbol,
                               const ulong position_ticket,
                               const double tp_price,
                               MqlTradeRequest &req)
{
   if(position_ticket == 0)
      return false;

   ZeroMemory(req);
   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = symbol;
   req.position = position_ticket;
   req.sl       = 0.0;
   req.tp       = tp_price;
   return true;
}

//+------------------------------------------------------------------+
//| Test helpers — lightweight mock stacks (no PositionsTotal).       |
//+------------------------------------------------------------------+
struct V2MockStack
{
   double entries[];
   double last_exit_price;
   bool   last_exit_valid;
   double current_add_pips;
};

void V2MockReset(V2MockStack &s)
{
   ArrayResize(s.entries, 0);
   s.last_exit_price = 0.0;
   s.last_exit_valid = false;
   s.current_add_pips = V2_ADD_PIPS_FLOOR;
}

void V2MockPopTop(V2MockStack &s)
{
   int n = ArraySize(s.entries);
   if(n <= 0)
      return;

   s.last_exit_price = s.entries[n - 1];
   s.last_exit_valid = true;
   ArrayResize(s.entries, n - 1);
   V2_OnOwnStackFlat(s.last_exit_valid, ArraySize(s.entries));
   V2_ResetAddPipsOnFlat(s.current_add_pips, ArraySize(s.entries));
}

void V2MockAppendEntry(V2MockStack &s, const double price, const bool is_reload)
{
   int n = ArraySize(s.entries);
   ArrayResize(s.entries, n + 1);
   s.entries[n] = price;
   if(is_reload)
      s.last_exit_valid = false;
   V2_AdvanceAddPipsOnAppend(s.current_add_pips, ArraySize(s.entries));
}

double V2MockComputeAddStepPips(const V2MockStack &s)
{
   if(s.last_exit_valid)
      return V2_ADD_PIPS_FLOOR;
   int depth_before = ArraySize(s.entries);
   if(depth_before <= 0)
      return 0.0;
   return V2_AddStepPipsForDepth(depth_before, s.current_add_pips);
}

#endif // FXMATRIX_V2_LOGIC_MQH
