//+------------------------------------------------------------------+
//| grind_closeby.mqh — hedging-account CloseBy queue (ported from v2) |
//+------------------------------------------------------------------+
#ifndef GRIND_CLOSEBY_MQH
#define GRIND_CLOSEBY_MQH

#include "grind_state.mqh"
#include "grind_api_counter.mqh"
#include "grind_telemetry.mqh"

#ifndef GRIND_CLOSEBY_MAX_RETRIES
#define GRIND_CLOSEBY_MAX_RETRIES 10
#endif

struct GrindCloseByTask
{
   ulong ticket1;
   ulong ticket2;
   int   retries;
   int   last_retcode;
};

GrindCloseByTask g_grind_long_closeby_queue[];
GrindCloseByTask g_grind_short_closeby_queue[];

// Unit-test hooks (no live PositionSelect / OrderSend when active).
bool   g_grind_closeby_test_active = false;
bool   g_grind_closeby_test_send_ok = true;
int    g_grind_closeby_test_send_retcode = TRADE_RETCODE_DONE;
int    g_grind_closeby_test_send_calls = 0;
string g_grind_closeby_test_last_critical = "";

struct GrindCloseByTestPosition
{
   ulong  ticket;
   string symbol;
   long   type;
};

GrindCloseByTestPosition g_grind_closeby_test_positions[];
int    g_grind_closeby_test_position_count = 0;
ulong  g_grind_closeby_test_success_ticket1 = 0;
ulong  g_grind_closeby_test_success_ticket2 = 0;

//+------------------------------------------------------------------+
void Grind_CloseByTestReset()
{
   g_grind_closeby_test_active = false;
   g_grind_closeby_test_send_ok = true;
   g_grind_closeby_test_send_retcode = TRADE_RETCODE_DONE;
   g_grind_closeby_test_send_calls = 0;
   g_grind_closeby_test_last_critical = "";
   g_grind_closeby_test_success_ticket1 = 0;
   g_grind_closeby_test_success_ticket2 = 0;
   ArrayResize(g_grind_closeby_test_positions, 0);
   g_grind_closeby_test_position_count = 0;
   ArrayResize(g_grind_long_closeby_queue, 0);
   ArrayResize(g_grind_short_closeby_queue, 0);
}

//+------------------------------------------------------------------+
bool Grind_CloseByTestSelectPosition(const ulong ticket)
{
   for(int i = 0; i < g_grind_closeby_test_position_count; i++) {
      if(g_grind_closeby_test_positions[i].ticket == ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
string Grind_CloseByTestPositionSymbol(const ulong ticket)
{
   for(int i = 0; i < g_grind_closeby_test_position_count; i++) {
      if(g_grind_closeby_test_positions[i].ticket == ticket)
         return g_grind_closeby_test_positions[i].symbol;
   }
   return "";
}

//+------------------------------------------------------------------+
long Grind_CloseByTestPositionType(const ulong ticket)
{
   for(int i = 0; i < g_grind_closeby_test_position_count; i++) {
      if(g_grind_closeby_test_positions[i].ticket == ticket)
         return g_grind_closeby_test_positions[i].type;
   }
   return -1;
}

//+------------------------------------------------------------------+
bool Grind_CloseBySelectPosition(const ulong ticket)
{
   if(g_grind_closeby_test_active)
      return Grind_CloseByTestSelectPosition(ticket);
   return PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
void Grind_QueueCloseBy(GrindCloseByTask &queue[],
                        const ulong ticket1,
                        const ulong ticket2)
{
   const int idx = ArraySize(queue);
   ArrayResize(queue, idx + 1);
   queue[idx].ticket1 = ticket1;
   queue[idx].ticket2 = ticket2;
   queue[idx].retries = 0;
   queue[idx].last_retcode = 0;
}

//+------------------------------------------------------------------+
int Grind_CloseByQueueSize(const GrindCloseByTask &queue[])
{
   return ArraySize(queue);
}

//+------------------------------------------------------------------+
bool Grind_CloseBySend(MqlTradeRequest &req, MqlTradeResult &res)
{
   if(g_grind_closeby_test_active) {
      g_grind_closeby_test_send_calls++;
      if(g_grind_closeby_test_success_ticket1 > 0
         && (req.position != g_grind_closeby_test_success_ticket1
             || req.position_by != g_grind_closeby_test_success_ticket2)) {
         res.retcode = (uint)TRADE_RETCODE_REJECT;
         return false;
      }
      res.retcode = (uint)g_grind_closeby_test_send_retcode;
      return g_grind_closeby_test_send_ok;
   }
   return Grind_OrderSendCounted(req, res);
}

//+------------------------------------------------------------------+
void Grind_ProcessCloseByQueue(GrindCloseByTask &queue[],
                               const ulong magic,
                               const bool verbose)
{
   const int q_size = ArraySize(queue);
   if(q_size == 0)
      return;

   for(int i = q_size - 1; i >= 0; i--) {
      queue[i].retries++;

      if(queue[i].retries >= GRIND_CLOSEBY_MAX_RETRIES) {
         const bool sel1 = Grind_CloseBySelectPosition(queue[i].ticket1);
         const long type1 = sel1 ? Grind_CloseByTestPositionType(queue[i].ticket1) : -1;
         const bool sel2 = Grind_CloseBySelectPosition(queue[i].ticket2);
         const long type2 = sel2 ? Grind_CloseByTestPositionType(queue[i].ticket2) : -1;

         if(sel1 && sel2) {
            const string crit = StringFormat(
               "GRIND_CLOSEBY_EXHAUSTED position=%I64u position_by=%I64u "
               "type1=%d type2=%d last_retcode=%d",
               queue[i].ticket1, queue[i].ticket2, type1, type2,
               queue[i].last_retcode);
            Print("CRITICAL ", crit);
            g_grind_closeby_test_last_critical = crit;
            Grind_TelemetryCritical(g_grind_telemetry_instance, "GRIND_CLOSEBY_EXHAUSTED", crit);
            g_grind_halted = true;
         } else if(verbose) {
            Print("INFO GRIND_CLOSEBY_EXHAUSTED one or both legs closed/unselectable "
                  "position=", queue[i].ticket1,
                  " position_by=", queue[i].ticket2,
                  " last_retcode=", queue[i].last_retcode);
         }

         ArrayRemove(queue, i, 1);
         continue;
      }

      if(!Grind_CloseBySelectPosition(queue[i].ticket1) ||
         !Grind_CloseBySelectPosition(queue[i].ticket2)) {
         if(g_grind_closeby_test_active) {
            if(verbose)
               Print("INFO GRIND_CLOSEBY retry ", queue[i].retries, "/",
                     GRIND_CLOSEBY_MAX_RETRIES,
                     " — positions not yet on ledger (test).");
            continue;
         }

         if(HistorySelectByPosition(queue[i].ticket1) ||
            HistorySelectByPosition(queue[i].ticket2)) {
            if(verbose)
               Print("INFO GRIND_CLOSEBY position already closed in history — discarding task.");
            ArrayRemove(queue, i, 1);
            continue;
         }
         if(verbose)
            Print("INFO GRIND_CLOSEBY retry ", queue[i].retries, "/",
                  GRIND_CLOSEBY_MAX_RETRIES, " — positions not yet on ledger.");
         continue;
      }

      string sym;
      if(g_grind_closeby_test_active)
         sym = Grind_CloseByTestPositionSymbol(queue[i].ticket1);
      else {
         PositionSelectByTicket(queue[i].ticket1);
         sym = PositionGetString(POSITION_SYMBOL);
      }

      string sym2;
      if(g_grind_closeby_test_active)
         sym2 = Grind_CloseByTestPositionSymbol(queue[i].ticket2);
      else {
         PositionSelectByTicket(queue[i].ticket2);
         sym2 = PositionGetString(POSITION_SYMBOL);
      }

      if(sym != sym2) {
         Print("ERROR GRIND_CLOSEBY inconsistent symbols ticket1=", queue[i].ticket1,
               " sym1=", sym, " ticket2=", queue[i].ticket2,
               " sym2=", sym2, " — removing task and halting.");
         ArrayRemove(queue, i, 1);
         g_grind_halted = true;
         return;
      }

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action = TRADE_ACTION_CLOSE_BY;
      req.position = queue[i].ticket1;
      req.position_by = queue[i].ticket2;
      req.symbol = sym;
      req.magic = magic;

      if(Grind_CloseBySend(req, res)) {
         if(res.retcode == TRADE_RETCODE_DONE) {
            if(verbose)
               Print("INFO GRIND_CLOSEBY success retry=", queue[i].retries,
                     " position=", queue[i].ticket1,
                     " position_by=", queue[i].ticket2);
            ArrayRemove(queue, i, 1);
         } else {
            queue[i].last_retcode = (int)res.retcode;
            if(verbose)
               Print("WARNING GRIND_CLOSEBY non-DONE retcode=", res.retcode,
                     " position=", queue[i].ticket1,
                     " position_by=", queue[i].ticket2);
         }
      } else {
         queue[i].last_retcode = (int)res.retcode;
         if(verbose)
            Print("WARNING GRIND_CLOSEBY send failed retcode=", res.retcode,
                  " retry ", queue[i].retries, "/", GRIND_CLOSEBY_MAX_RETRIES,
                  " position=", queue[i].ticket1,
                  " position_by=", queue[i].ticket2);
      }
   }
}

//+------------------------------------------------------------------+
void Grind_ProcessCloseByQueues(const ulong magic, const bool verbose)
{
   Grind_ProcessCloseByQueue(g_grind_long_closeby_queue, magic, verbose);
   Grind_ProcessCloseByQueue(g_grind_short_closeby_queue, magic, verbose);
}

#endif // GRIND_CLOSEBY_MQH
