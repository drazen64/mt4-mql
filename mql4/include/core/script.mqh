
#define __TYPE__         MT_SCRIPT
#define __lpSuperContext NULL
int     __WHEREAMI__   = NULL;                                       // current MQL RootFunction: RF_INIT | RF_START | RF_DEINIT


/**
 * Globale init()-Funktion f�r Scripte.
 *
 * @return int - Fehlerstatus
 */
int init() {
   if (__STATUS_OFF)
      return(last_error);

   if (__WHEREAMI__ == NULL)                                         // Aufruf durch Terminal, in Scripten sind alle Variablen zur�ckgesetzt
      __WHEREAMI__ = RF_INIT;

   SyncMainContext_init(__ExecutionContext, __TYPE__, WindowExpertName(), UninitializeReason(), SumInts(__INIT_FLAGS__), SumInts(__DEINIT_FLAGS__), Symbol(), Period(), __lpSuperContext, IsTesting(), IsVisualMode(), IsOptimization(), WindowHandle(Symbol(), NULL), WindowOnDropped());


   // (1) Initialisierung abschlie�en, wenn der Kontext unvollst�ndig ist
   if (!UpdateExecutionContext())
      if (UpdateProgramStatus()) return(last_error);


   // (2) stdlib initialisieren
   int iNull[];
   int error = stdlib.init(iNull);
   if (IsError(error)) {
      if (UpdateProgramStatus(SetLastError(error))) return(last_error);
   }

                                                                     // #define INIT_TIMEZONE               in stdlib.init()
   // (3) user-spezifische Init-Tasks ausf�hren                      // #define INIT_PIPVALUE
   int initFlags = ec_InitFlags(__ExecutionContext);                 // #define INIT_BARS_ON_HIST_UPDATE
                                                                     // #define INIT_CUSTOMLOG
   if (initFlags & INIT_PIPVALUE && 1) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                // schl�gt fehl, wenn kein Tick vorhanden ist
      if (IsError(catch("init(1)"))) if (UpdateProgramStatus()) return( last_error);
      if (!TickSize)                                            return(_last_error(UpdateProgramStatus(catch("init(2)  MarketInfo(MODE_TICKSIZE) = 0", ERR_INVALID_MARKET_DATA))));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (IsError(catch("init(3)"))) if (UpdateProgramStatus()) return( last_error);
      if (!tickValue)                                           return(_last_error(UpdateProgramStatus(catch("init(4)  MarketInfo(MODE_TICKVALUE) = 0", ERR_INVALID_MARKET_DATA))));
   }
   if (initFlags & INIT_BARS_ON_HIST_UPDATE && 1) {}                 // noch nicht implementiert


   // (4) User-spezifische init()-Routinen *k�nnen*, m�ssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgef�hrt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zur�ckkehrt.
   // Der Postprocessing-Hook wird ausgef�hrt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zur�ckgeben.
   error = onInit();                                                                      // Preprocessing-Hook
   if (!error) {                                                                          //
      switch (UninitializeReason()) {                                                     //
         case UR_PARAMETERS : error = onInitParameterChange(); break;                     //
         case UR_CHARTCHANGE: error = onInitChartChange();     break;                     //
         case UR_ACCOUNT    : error = onInitAccountChange();   break;                     //
         case UR_CHARTCLOSE : error = onInitChartClose();      break;                     //
         case UR_UNDEFINED  : error = onInitUndefined();       break;                     //
         case UR_REMOVE     : error = onInitRemove();          break;                     //
         case UR_RECOMPILE  : error = onInitRecompile();       break;                     //
         // build > 509                                                                   //
         case UR_TEMPLATE   : error = onInitTemplate();        break;                     //
         case UR_INITFAILED : error = onInitFailed();          break;                     //
         case UR_CLOSE      : error = onInitClose();           break;                     //
                                                                                          //
         default: return(_last_error(UpdateProgramStatus(catch("init(5)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR))));
      }                                                                                   //
   }                                                                                      //
   if (IsError(error)) SetLastError(error);                                               //
   UpdateProgramStatus();                                                                 //
                                                                                          //
   if (error != -1) {                                                                     //
      error = afterInit();                                                                // Postprocessing-Hook
      if (IsError(error)) SetLastError(error);                                            //
      UpdateProgramStatus();                                                              //
   }                                                                                      //

   UpdateProgramStatus(catch("init(6)"));
   return(last_error);
}


/**
 * Globale start()-Funktion f�r Scripte.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_OFF) {                                                        // init()-Fehler abfangen
      string msg = WindowExpertName() +": switched off ("+ ifString(!__STATUS_OFF.reason, "unknown reason", ErrorToStr(__STATUS_OFF.reason)) +")";
      Comment(NL + NL + NL + msg);                                            // 3 Zeilen Abstand f�r Instrumentanzeige und ggf. vorhandene Legende
      debug("start(1)  "+ msg);
      return(last_error);
   }

   __WHEREAMI__ = RF_START;
   SyncMainContext_start(__ExecutionContext);

   Tick++; zTick++;                                                           // einfache Z�hler, die konkreten Werte haben keine Bedeutung
   Tick.prevTime  = Tick.Time;
   Tick.Time      = MarketInfo(Symbol(), MODE_TIME);                          // TODO: !!! MODE_TIME ist im synthetischen Chart NULL               !!!
   Tick.isVirtual = true;                                                     // TODO: !!! MODE_TIME und TimeCurrent() sind im Tester-Chart falsch !!!
   ValidBars      = -1;
   ChangedBars    = -1;

   if (!Tick.Time) {
      int error = GetLastError();
      if (error!=NO_ERROR) /*&&*/ if (error!=ERR_SYMBOL_NOT_AVAILABLE) {      // ERR_SYMBOL_NOT_AVAILABLE vorerst ignorieren, da ein Offline-Chart beim ersten Tick
         if (UpdateProgramStatus(catch("start(2)", error)))                   // nicht sicher detektiert werden kann
            return(last_error);
      }
   }


   // (1) init() war immer erfolgreich


   // (2) Abschlu� der Chart-Initialisierung �berpr�fen
   if (!(ec_InitFlags(__ExecutionContext) & INIT_NO_BARS_REQUIRED))           // Bars kann 0 sein, wenn das Script auf einem leeren Chart startet (Waiting for update...)
      if (!Bars)                                                              // oder der Chart beim Terminal-Start noch nicht vollst�ndig initialisiert ist
         return(_last_error(UpdateProgramStatus(catch("start(3)  Bars = 0", ERS_TERMINAL_NOT_YET_READY))));


   // (3) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR)
      if (UpdateProgramStatus(SetLastError(stdlib.GetLastError()))) return(last_error);


   // (4) Main-Funktion aufrufen
   onStart();



   // lokaler Error: last_error
   catch("start(5)", error);

   // MQL-Error:     mql_error
   int mql_error = ec_MqlError(__ExecutionContext);
   debug("start(0.1)  ec.MqlError="+ ErrorToStr(mql_error));

   // DLL-Error:     dll_error
   int dll_error; // = ec_MqlError(__ExecutionContext);

   if (last_error || mql_error || dll_error)
      UpdateProgramStatus(last_error, mql_error, dll_error);
   return(last_error);
}


/**
 * Globale deinit()-Funktion f�r Scripte.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ = RF_DEINIT;
   SyncMainContext_deinit(__ExecutionContext, UninitializeReason());


   // (1) User-spezifische deinit()-Routinen *k�nnen*, m�ssen aber nicht implementiert werden.
   //
   // Die User-Routinen werden ausgef�hrt, wenn der Preprocessing-Hook (falls implementiert) ohne Fehler zur�ckkehrt.
   // Der Postprocessing-Hook wird ausgef�hrt, wenn weder der Preprocessing-Hook (falls implementiert) noch die User-Routinen
   // (falls implementiert) -1 zur�ckgeben.
   int error = onDeinit();                                                       // Preprocessing-Hook
                                                                                 //
   if (!error) {                                                                 //
      switch (UninitializeReason()) {                                            //
         case UR_PARAMETERS : error = onDeinitParameterChange(); break;          //
         case UR_CHARTCHANGE: error = onDeinitChartChange();     break;          //
         case UR_ACCOUNT    : error = onDeinitAccountChange();   break;          //
         case UR_CHARTCLOSE : error = onDeinitChartClose();      break;          //
         case UR_UNDEFINED  : error = onDeinitUndefined();       break;          //
         case UR_REMOVE     : error = onDeinitRemove();          break;          //
         case UR_RECOMPILE  : error = onDeinitRecompile();       break;          //
         // build > 509                                                          //
         case UR_TEMPLATE   : error = onDeinitTemplate();        break;          //
         case UR_INITFAILED : error = onDeinitFailed();          break;          //
         case UR_CLOSE      : error = onDeinitClose();           break;          //
                                                                                 //
         default:                                                                //
            UpdateProgramStatus(catch("deinit(1)  unknown UninitializeReason = "+ UninitializeReason(), ERR_RUNTIME_ERROR));
            LeaveContext(__ExecutionContext);                                    //
            return(last_error);                                                  //
      }                                                                          //
   }                                                                             //
   if (IsError(error)) SetLastError(error);                                      //
   UpdateProgramStatus();                                                        //
                                                                                 //
   if (error != -1) {                                                            //
      error = afterDeinit();                                                     // Postprocessing-Hook
      if (IsError(error)) SetLastError(error);                                   //
      UpdateProgramStatus();                                                     //
   }                                                                             //


   // (2) User-spezifische Deinit-Tasks ausf�hren
   if (!error) {
      // ...
   }


   // (3) stdlib deinitialisieren
   error = stdlib.deinit(__ExecutionContext);
   if (IsError(error))
      SetLastError(error);


   UpdateProgramStatus(catch("deinit(2)"));
   LeaveContext(__ExecutionContext);
   return(last_error); __DummyCalls();
}


/**
 * Gibt die ID des aktuellen Deinit()-Szenarios zur�ck. Kann nur in deinit() aufgerufen werden.
 *
 * @return int - ID oder NULL, falls ein Fehler auftrat
 */
int DeinitReason() {
   return(!catch("DeinitReason(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Whether or not the current program is an expert.
 *
 * @return bool
 */
bool IsExpert() {
   return(false);
}


/**
 * Whether or not the current program is a script.
 *
 * @return bool
 */
bool IsScript() {
   return(true);
}


/**
 * Whether or not the current program is an indicator.
 *
 * @return bool
 */
bool IsIndicator() {
   return(false);
}


/**
 * Whether or not the current module is a library.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
}


/**
 * Update the script's EXECUTION_CONTEXT.
 *
 * @return bool - success status
 */
bool UpdateExecutionContext() {
   // globale Variablen initialisieren
   __NAME__       = WindowExpertName();
   __CHART        = true;
   __LOG          = true;
   __LOG_CUSTOM   = false;                                                                   // Custom-Logging gibt es vorerst nur f�r Experts

   PipDigits      = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints      = MathRound(MathPow(10, Digits & 1));                   PipPoint          = PipPoints;
   Pip            = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat    = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);

   N_INF = MathLog(0);
   P_INF = -N_INF;
   NaN   =  N_INF - N_INF;

   return(!catch("UpdateExecutionContext(1)"));
}


/**
 * Handler f�r im Script auftretende Fehler. Zur Zeit wird der Fehler nur angezeigt.
 *
 * @param  string location - Ort, an dem der Fehler auftrat
 * @param  string message  - Fehlermeldung
 * @param  int    error    - zu setzender Fehlercode
 *
 * @return int - derselbe Fehlercode
 */
int HandleScriptError(string location, string message, int error) {
   if (StringLen(location) > 0)
      location = " :: "+ location;

   PlaySoundEx("Windows Chord.wav");
   MessageBox(message, "Script "+ __NAME__ + location, MB_ICONERROR|MB_OK);

   return(SetLastError(error));
}


/**
 * Check the program's error status and activate the flag __STATUS_OFF accordingly.
 *
 * @param  int last_error - atm ignored
 * @param  int mql_error  - atm ignored
 * @param  int dll_error  - atm ignored
 *
 * @return bool - whether or not the flag __STATUS_OFF is activated
 */
bool UpdateProgramStatus(int value=NULL, int mql_error=NULL, int dll_error=NULL) {
   switch (last_error) {
      case NO_ERROR                  :
      case ERS_HISTORY_UPDATE        :
    //case ERS_TERMINAL_NOT_YET_READY:                               // in scripts ERS_TERMINAL_NOT_YET_READY is regular error
      case ERS_EXECUTION_STOPPING    : break;

      default:
         __STATUS_OFF        = true;
         __STATUS_OFF.reason = last_error;
   }
   return(__STATUS_OFF);

   // dummy call (suppress compiler warnings)
   HandleScriptError(NULL, NULL, NULL);
}



// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "stdlib1.ex4"
   int    stdlib.init  (int tickData[]);
   int    stdlib.start (/*EXECUTION_CONTEXT*/int ec[], int tick, datetime tickTime, int validBars, int changedBars);
   int    stdlib.deinit(/*EXECUTION_CONTEXT*/int ec[]);

   int    onInitAccountChange();
   int    onInitChartChange();
   int    onInitChartClose();
   int    onInitParameterChange();
   int    onInitRecompile();
   int    onInitRemove();
   int    onInitUndefined();
   // build > 509
   int    onInitTemplate();
   int    onInitFailed();
   int    onInitClose();

   int    onDeinitAccountChange();
   int    onDeinitChartChange();
   int    onDeinitChartClose();
   int    onDeinitParameterChange();
   int    onDeinitRecompile();
   int    onDeinitRemove();
   int    onDeinitUndefined();
   // build > 509
   int    onDeinitTemplate();
   int    onDeinitFailed();
   int    onDeinitClose();

   string GetWindowText(int hWnd);

#import "Expander.dll"
   int    ec_DllError         (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_hChartWindow     (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_InitFlags        (/*EXECUTION_CONTEXT*/int ec[]);
   int    ec_MqlError         (/*EXECUTION_CONTEXT*/int ec[]);

   bool   SyncMainContext_init  (int ec[], int programType, string programName, int uninitReason, int initFlags, int deinitFlags, string symbol, int period, int lpSec, int isTesting, int isVisualMode, int isOptimization, int hChart, int subChartDropped);
   bool   SyncMainContext_start (int ec[]);
   bool   SyncMainContext_deinit(int ec[], int uninitReason);

#import "user32.dll"
   int    GetParent(int hWnd);

#import
