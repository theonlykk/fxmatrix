//+------------------------------------------------------------------+
//| fxmatrix_v2_geometry.mqh — grid spacing geometry (Phase 1 shared) |
//| Extracted from fxmatrix_v2_logic.mqh for parameterized V2.        |
//+------------------------------------------------------------------+
#ifndef FXMATRIX_V2_GEOMETRY_MQH
#define FXMATRIX_V2_GEOMETRY_MQH

#ifndef V2_ADD_PIPS_FLOOR
#define V2_ADD_PIPS_FLOOR    9.0
#endif
#ifndef V2_WIDEN_RATIO
#define V2_WIDEN_RATIO       1.304
#endif
#ifndef V2_ADD_PIPS_CEILING
#define V2_ADD_PIPS_CEILING  1000.0
#endif
#ifndef V2_EXIT_PIPS
#define V2_EXIT_PIPS         3.0
#endif

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
//+------------------------------------------------------------------+
double V2_AddStepPipsForDepth(const int depth_before, const double current_add_pips)
{
   if(depth_before < 3)
      return V2_ADD_PIPS_FLOOR;
   return current_add_pips;
}

//+------------------------------------------------------------------+
void V2_AdvanceAddPipsOnAppend(double &current_add_pips, const int depth_after)
{
   if(depth_after >= 3)
      current_add_pips = MathMin(V2_ADD_PIPS_CEILING, current_add_pips * V2_WIDEN_RATIO);
}

//+------------------------------------------------------------------+
void V2_ResetAddPipsOnFlat(double &current_add_pips, const int layer_count)
{
   if(layer_count == 0)
      current_add_pips = V2_ADD_PIPS_FLOOR;
}

//+------------------------------------------------------------------+
void V2_OnOwnStackFlat(bool &last_exit_valid, const int layer_count)
{
   if(layer_count == 0)
      last_exit_valid = false;
}

#endif // FXMATRIX_V2_GEOMETRY_MQH
