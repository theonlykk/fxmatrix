//+------------------------------------------------------------------+
//| DataExporterEA.mq5 - standalone Tester-side M5 bar CSV exporter |
//| Writes to Terminal\Common\Files for OOS data extraction.        |
//+------------------------------------------------------------------+
#property version   "1.00"
#property description "Exports M5 bars visible in Strategy Tester to CSV (FILE_COMMON)."

input datetime InpFrom    = D'2022.08.01 00:00:00';
input datetime InpTo      = D'2022.11.01 23:59:59';
input string   InpOutFile = "GBPUSD_truss_crisis_oos.csv";

string FormatDateTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return StringFormat("%04d-%02d-%02d %02d:%02d:%02d",
                       dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
  }

bool ExportRatesToCsv()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, false);

   int copied = -1;
   int err = 0;

   // Primary: all bars visible to the Tester for this symbol/period.
   int bars = Bars(_Symbol, PERIOD_M5);
   ResetLastError();
   copied = CopyRates(_Symbol, PERIOD_M5, 0, bars, rates);
   err = GetLastError();

   // Fallback: datetime range with short retry loop (4401 = history updating).
   if(copied <= 1)
     {
      for(int attempt = 0; attempt < 60 && copied <= 1; attempt++)
        {
         ResetLastError();
         copied = CopyRates(_Symbol, PERIOD_M5, InpFrom, InpTo, rates);
         err = GetLastError();
         if(copied <= 1 && err == 4401)
            Sleep(100);
         else
            break;
        }
     }

   Print("DataExporterEA CopyRates copied=", copied, " err=", err,
         " bars=", bars, " symbol=", _Symbol,
         " from=", TimeToString(InpFrom), " to=", TimeToString(InpTo));

   if(copied <= 1)
     {
      Print("DataExporterEA FAIL: insufficient bars (", copied, ")");
      return false;
     }

   // Trim to requested window if we copied the full tester series.
   int start = 0;
   int end = copied - 1;
   while(start < copied && rates[start].time < InpFrom)
      start++;
   while(end >= 0 && rates[end].time > InpTo)
      end--;
   if(end < start)
     {
      Print("DataExporterEA FAIL: no bars within requested window");
      return false;
     }

   int handle = FileOpen(InpOutFile, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      Print("DataExporterEA FileOpen failed err=", GetLastError(), " file=", InpOutFile);
      return false;
     }

   FileWriteString(handle, "datetime,OPEN,HIGH,LOW,CLOSE,SPREAD\r\n");
   int written = 0;
   for(int i = start; i <= end; i++)
     {
      string line = StringFormat("%s,%.5f,%.5f,%.5f,%.5f,%d\r\n",
                                 FormatDateTime(rates[i].time),
                                 rates[i].open,
                                 rates[i].high,
                                 rates[i].low,
                                 rates[i].close,
                                 rates[i].spread);
      FileWriteString(handle, line);
      written++;
     }
   FileClose(handle);

   Print("DataExporterEA WROTE ", InpOutFile, " bars=", written,
         " first=", TimeToString(rates[start].time),
         " last=", TimeToString(rates[end].time));
   return true;
  }

int OnInit()
  {
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ExportRatesToCsv();
  }

void OnTick()
  {
  }

double OnTester()
  {
   return 0.0;
  }
