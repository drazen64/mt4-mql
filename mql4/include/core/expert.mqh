
#define __TYPE__         T_EXPERT
#define __lpSuperContext NULL

#include <history.mqh>
#include <iCustom/icChartInfos.mqh>


// Variablen f�r Teststatistiken
datetime Test.fromDate,    Test.toDate;
int      Test.startMillis, Test.stopMillis;                          // in Millisekunden


/**
 * Globale init()-Funktion f�r Expert Adviser.
 *
 * Bei Aufruf durch das Terminal wird der letzte Errorcode 'last_error' in 'prev_error' gespeichert und vor Abarbeitung
 * zur�ckgesetzt.
 *
 * @return int - Fehlerstatus
 */
int init() { // throws ERS_TERMINAL_NOT_READY
   if (__STATUS_ERROR)
      return(last_error);

   if (__WHEREAMI__ == NULL) {                                       // Aufruf durch Terminal
      __WHEREAMI__ = FUNC_INIT;
      prev_error   = last_error;
      last_error   = NO_ERROR;
   }


   // (1) EXECUTION_CONTEXT initialisieren
   if (!ec.Signature(__ExecutionContext))
      if (IsError(InitExecutionContext()))
         return(last_error);


   // (2) stdlib (re-)initialisieren
   int iNull[];
   int error = stdlib.init(__ExecutionContext, iNull);
   if (IsError(error))
      return(SetLastError(error));


   // (3) in Experts immer auch die history-lib (re-)initialisieren
   error = history_init(__ExecutionContext);
   if (IsError(error))
      return(SetLastError(error));                                            // #define INIT_TIMEZONE               in stdlib.init()
                                                                              // #define INIT_PIPVALUE
                                                                              // #define INIT_BARS_ON_HIST_UPDATE
   // (4) user-spezifische Init-Tasks ausf�hren                               // #define INIT_CUSTOMLOG
   int initFlags = ec.InitFlags(__ExecutionContext);

   if (_bool(initFlags & INIT_PIPVALUE)) {
      TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);                         // schl�gt fehl, wenn kein Tick vorhanden ist
      error = GetLastError();
      if (IsError(error)) {                                                   // - Symbol nicht subscribed (Start, Account-/Templatewechsel), Symbol kann noch "auftauchen"
         if (error == ERR_UNKNOWN_SYMBOL)                                     // - synthetisches Symbol im Offline-Chart
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERS_TERMINAL_NOT_READY)));
         return(catch("init(1)", error));
      }
      if (!TickSize) return(debug("init()   MarketInfo(MODE_TICKSIZE) = 0", SetLastError(ERS_TERMINAL_NOT_READY)));

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      error = GetLastError();
      if (IsError(error)) {
         if (error == ERR_UNKNOWN_SYMBOL)                                     // siehe oben bei MODE_TICKSIZE
            return(debug("init()   MarketInfo() => ERR_UNKNOWN_SYMBOL", SetLastError(ERS_TERMINAL_NOT_READY)));
         return(catch("init(2)", error));
      }
      if (!tickValue) return(debug("init()   MarketInfo(MODE_TICKVALUE) = 0", SetLastError(ERS_TERMINAL_NOT_READY)));
   }
   if (_bool(initFlags & INIT_BARS_ON_HIST_UPDATE)) {}                        // noch nicht implementiert


   // (5) ggf. EA's aktivieren
   int reasons1[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE };
   if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
      error = Toolbar.Experts(true);                                          // !!! TODO: Bug, wenn mehrere EA's den Modus gleichzeitig umschalten
      if (IsError(error))
         return(SetLastError(error));
   }


   // (6) nach Neuladen explizit Orderkontext zur�cksetzen (siehe MQL.doc)
   int reasons2[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE, REASON_ACCOUNT };
   if (IntInArray(reasons2, UninitializeReason()))
      OrderSelect(0, SELECT_BY_TICKET);

                                                                              // User-Routinen *k�nnen*, m�ssen aber nicht implementiert werden.
   // (7) user-spezifische init()-Routinen aufrufen                           //
   onInit();                                                                  // Preprocessing-Hook
                                                                              //
   if (!__STATUS_ERROR) {                                                     //
      switch (UninitializeReason()) {                                         //
         case REASON_PARAMETERS : error = onInitParameterChange(); break;     //
         case REASON_CHARTCHANGE: error = onInitChartChange();     break;     //
         case REASON_ACCOUNT    : error = onInitAccountChange();   break;     //
         case REASON_CHARTCLOSE : error = onInitChartClose();      break;     //
         case REASON_UNDEFINED  : error = onInitUndefined();       break;     //
         case REASON_REMOVE     : error = onInitRemove();          break;     //
         case REASON_RECOMPILE  : error = onInitRecompile();       break;     //
      }                                                                       //
   }                                                                          //
                                                                              //
   afterInit();                                                               // Postprocessing-Hook wird immer ausgef�hrt (auch bei __STATUS_ERROR)
   ShowStatus(NO_ERROR);

   if (__STATUS_ERROR)
      return(last_error);


   // (8) Au�er bei REASON_CHARTCHANGE nicht auf den n�chsten echten Tick warten, sondern selbst einen Tick schicken.
   if (IsTesting()) {
      Test.fromDate    = TimeCurrent();
      Test.startMillis = GetTickCount();
   }
   else if (UninitializeReason() != REASON_CHARTCHANGE) {                     // Ganz zum Schlu�, da Ticks verloren gehen, wenn die entsprechende Windows-Message
      error = Chart.SendTick(false);                                          // vor Verlassen von init() verarbeitet wird.
      if (IsError(error))
         SetLastError(error);
   }
   return(last_error|catch("init(3)"));
}


/**
 * Globale start()-Funktion f�r Expert Adviser.
 *
 * Erfolgt der Aufruf nach einem vorherigem init()-Aufruf und init() kehrte mit dem Fehler ERS_TERMINAL_NOT_READY zur�ck,
 * wird init() erneut ausgef�hrt. Bei erneutem Fehler bricht start() ab.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS_ERROR)
      return(ShowStatus(last_error));


   // "Time machine"-Bug im Tester abfangen
   if (IsTesting()) {
      static datetime time, lastTime;
      time = TimeCurrent();
      if (time < lastTime)
         return(ShowStatus(catch("start(1)   Bug in TimeCurrent()/MarketInfo(MODE_TIME) testen !!!\nTime is running backward here:   previous='"+ TimeToStr(lastTime, TIME_FULL) +"'   current='"+ TimeToStr(time, TIME_FULL) +"'", ERR_RUNTIME_ERROR)));
      lastTime = time;
   }


   Tick++; Ticks = Tick;                                                   // einfacher Z�hler, der konkrete Wert hat keine Bedeutung
   Tick.prevTime = Tick.Time;
   Tick.Time     = MarketInfo(Symbol(), MODE_TIME);
   ValidBars     = -1;
   ChangedBars   = -1;


   // (1) Falls wir aus init() kommen, pr�fen, ob es erfolgreich war
   if (__WHEREAMI__ == FUNC_INIT) {
      __WHEREAMI__ = ec.setWhereami(__ExecutionContext, FUNC_START);

      if (IsLastError()) {
         if (last_error != ERS_TERMINAL_NOT_READY)                         // init() ist mit hartem Fehler zur�ckgekehrt
            return(ShowStatus(last_error));

         if (IsError(init())) {                                            // init() ist mit weichem Fehler zur�ckgekehrt => erneut aufrufen
            __WHEREAMI__ = ec.setWhereami(__ExecutionContext, FUNC_INIT);  // erneuter Fehler (hart oder weich), __WHEREAMI__ zur�cksetzen
            return(ShowStatus(last_error));
         }
      }
      last_error = NO_ERROR;                                               // init() war erfolgreich
   }
   else {
      prev_error = last_error;                                             // weiterer Tick: last_error sichern und zur�cksetzen
      last_error = NO_ERROR;
   }


   // (2) bei Bedarf Input-Dialog aufrufen
   if (__STATUS_RELAUNCH_INPUT) {
      __STATUS_RELAUNCH_INPUT = false;
      start.RelaunchInputDialog();
      return(ShowStatus(last_error));
   }


   // (3) Abschlu� der Chart-Initialisierung �berpr�fen (kann bei Terminal-Start auftreten)
   if (!Bars)
      return(ShowStatus(SetLastError(debug("start()   Bars=0", ERS_TERMINAL_NOT_READY))));


   // (4) stdLib benachrichtigen
   if (stdlib.start(__ExecutionContext, Tick, Tick.Time, ValidBars, ChangedBars) != NO_ERROR)
      return(ShowStatus(SetLastError(stdlib.GetLastError())));


   // (5) Main-Funktion aufrufen und auswerten
   onTick();

   int error = GetLastError();
   if (error != NO_ERROR)
      catch("start(2)", error);


   // (6) im Tester
   if (IsTesting()) {
      if (IsVisualMode()) {                                                // bei VisualMode=On ChartInfos anzeigen
         if (__STATUS_ERROR || !icChartInfos(PERIOD_H1))                   // nach Fehler anhalten
            Tester.Stop();
      }
      else {
         if (__STATUS_ERROR)                                               // nach Fehler anhalten
            Tester.Stop();
         return(last_error);                                               // kein ShowStatus()
      }
   }


   // (7) Statusanzeige
   return(ShowStatus(last_error));
}


/**
 * Globale deinit()-Funktion f�r Expert Adviser.
 *
 * @return int - Fehlerstatus
 *
 *
 * NOTE: Bei VisualMode=Off und regul�rem Testende (Testperiode zu Ende = REASON_UNDEFINED) bricht das Terminal komplexere deinit()-Funktionen verfr�ht ab.
 *       afterDeinit() und stdlib.deinit() werden u.U. schon nicht mehr ausgef�hrt.
 *
 *       Workaround: Testperiode auslesen (Controls), letzten Tick ermitteln (Historydatei) und Test nach letztem Tick per Tester.Stop() beenden.
 *                   Alternativ bei EA's, die dies unterst�tzen, Testende vors regul�re Testende der Historydatei setzen.
 */
int deinit() {
   __WHEREAMI__ =                               FUNC_DEINIT;
   ec.setWhereami          (__ExecutionContext, FUNC_DEINIT         );
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason());


   if (IsTesting()) {
      Test.toDate     = TimeCurrent();
      Test.stopMillis = GetTickCount();
   }


   // (1) User-spezifische deinit()-Routinen aufrufen                            // User-Routinen *k�nnen*, m�ssen aber nicht implementiert werden.
   int error = onDeinit();                                                       // Preprocessing-Hook
                                                                                 //
   if (error != -1) {                                                            // - deinit() bricht *nicht* ab, falls eine der User-Routinen einen Fehler zur�ckgibt.
      switch (UninitializeReason()) {                                            // - deinit() bricht ab, falls eine der User-Routinen -1 zur�ckgibt.
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;      //
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;      //
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;      //
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;      //
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;      //
         case REASON_REMOVE     : error = onDeinitRemove();          break;      //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;      //
      }                                                                          //
   }                                                                             //
                                                                                 //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausf�hren
   if (error != -1) {
      // ...
   }


   // (3) stdlib deinitialisieren
   error = stdlib.deinit(__ExecutionContext);
   if (IsError(error))
      SetLastError(error);

   return(last_error);
}


#import "structs1.ex4"
   int  ec.Signature            (/*EXECUTION_CONTEXT*/int ec[]                         );
   int  ec.InitFlags            (/*EXECUTION_CONTEXT*/int ec[]                         );

   int  ec.setSignature         (/*EXECUTION_CONTEXT*/int ec[], int  signature         );
   int  ec.setLpName            (/*EXECUTION_CONTEXT*/int ec[], int  lpName            );
   int  ec.setType              (/*EXECUTION_CONTEXT*/int ec[], int  type              );
   int  ec.setChartProperties   (/*EXECUTION_CONTEXT*/int ec[], int  chartProperties   );
   int  ec.setInitFlags         (/*EXECUTION_CONTEXT*/int ec[], int  initFlags         );
   int  ec.setDeinitFlags       (/*EXECUTION_CONTEXT*/int ec[], int  deinitFlags       );
   int  ec.setUninitializeReason(/*EXECUTION_CONTEXT*/int ec[], int  uninitializeReason);
   int  ec.setWhereami          (/*EXECUTION_CONTEXT*/int ec[], int  whereami          );
   bool ec.setLogging           (/*EXECUTION_CONTEXT*/int ec[], bool logging           );
   int  ec.setLpLogFile         (/*EXECUTION_CONTEXT*/int ec[], int  lpLogFile         );
   int  ec.setLastError         (/*EXECUTION_CONTEXT*/int ec[], int  lastError         );
#import


/**
 * Initialisiert den EXECUTION_CONTEXT des Experts.
 *
 * @return int - Fehlerstatus
 */
int InitExecutionContext() {
   if (ec.Signature(__ExecutionContext) != 0) return(catch("InitExecutionContext(1)   signature of EXECUTION_CONTEXT not NULL = "+ EXECUTION_CONTEXT.toStr(__ExecutionContext, false), ERR_ILLEGAL_STATE));


   // (1) Speicher f�r Programm- und LogFileName alloziieren
   string names[2]; names[0] = WindowExpertName();                                              // Programm-Name (L�nge konstant)
                    names[1] = CreateString(MAX_PATH);                                          // LogFileName   (L�nge variabel)

   int  lpNames[3]; CopyMemory(GetStringsAddress(names)+ 4, GetBufferAddress(lpNames),   4);    // Zeiger auf beide Strings holen
                    CopyMemory(GetStringsAddress(names)+12, GetBufferAddress(lpNames)+4, 4);

                    CopyMemory(GetBufferAddress(lpNames)+8, lpNames[1], 1);                     // LogFileName mit <NUL> initialisieren (lpNames[2] = <NUL>)


   // (2) globale Variablen initialisieren
   int initFlags   = SumInts(__INIT_FLAGS__  );
   int deinitFlags = SumInts(__DEINIT_FLAGS__);

   __NAME__        = names[0];
   IsChart         = !IsTesting() || IsVisualMode();
 //IsOfflineChart  = IsChart && ???
   __LOG           = IsLogging();
   __LOG_CUSTOM    = initFlags & INIT_CUSTOMLOG;

   PipDigits       = Digits & (~1);                                        SubPipDigits      = PipDigits+1;
   PipPoints       = MathRound(MathPow(10, Digits<<31>>31));               PipPoint          = PipPoints;
   Pip             = NormalizeDouble(1/MathPow(10, PipDigits), PipDigits); Pips              = Pip;
   PipPriceFormat  = StringConcatenate(".", PipDigits);                    SubPipPriceFormat = StringConcatenate(PipPriceFormat, "'");
   PriceFormat     = ifString(Digits==PipDigits, PipPriceFormat, SubPipPriceFormat);


   // (3) EXECUTION_CONTEXT initialisieren
   ArrayInitialize(__ExecutionContext, 0);

   ec.setSignature         (__ExecutionContext, GetBufferAddress(__ExecutionContext)                                    );
   ec.setLpName            (__ExecutionContext, lpNames[0]                                                              );
   ec.setType              (__ExecutionContext, __TYPE__                                                                );
   ec.setChartProperties   (__ExecutionContext, ifInt(IsOfflineChart, CP_OFFLINE_CHART, 0) | ifInt(IsChart, CP_CHART, 0));
 //ec.setLpSuperContext    ...bereits initialisiert
   ec.setInitFlags         (__ExecutionContext, initFlags                                                               );
   ec.setDeinitFlags       (__ExecutionContext, deinitFlags                                                             );
   ec.setUninitializeReason(__ExecutionContext, UninitializeReason()                                                    );
   ec.setWhereami          (__ExecutionContext, __WHEREAMI__                                                            );
   ec.setLogging           (__ExecutionContext, __LOG                                                                   );
   ec.setLpLogFile         (__ExecutionContext, lpNames[1]                                                              );
 //ec.setLastError         ...bereits initialisiert


   if (IsError(catch("InitExecutionContext(2)")))
      ArrayInitialize(__ExecutionContext, 0);
   return(last_error);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein Expert Adviser ist.
 *
 * @return bool
 */
bool IsExpert() {
   return(true);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein im Tester laufender Expert ist.
 *
 * @return bool
 */
bool Expert.IsTesting() {
   return(IsTesting());
}


/**
 * Ob das aktuell ausgef�hrte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   return(false);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein im Tester laufender Indikator ist.
 *
 * @return bool
 */
bool Indicator.IsTesting() {
   return(false);
}


/**
 * Ob das aktuelle Programm durch ein anderes Programm ausgef�hrt wird.
 *
 * @return bool
 */
bool Indicator.IsSuperContext() {
   return(false);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   return(false);
}


/**
 * Ob das aktuell ausgef�hrte Programm ein im Tester laufendes Script ist.
 *
 * @return bool
 */
bool Script.IsTesting() {
   return(false);
}


/**
 * Ob das aktuell ausgef�hrte Modul eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(false);
}


/**
 * Ob das aktuelle Programm im Tester ausgef�hrt wird.
 *
 * @return bool
 */
bool This.IsTesting() {
   return(IsTesting());
}


/**
 * Pr�ft, ob der aktuelle Tick in den angegebenen Timeframes ein BarOpen-Event darstellt. Auch bei wiederholten Aufrufen w�hrend
 * desselben Ticks wird das Event korrekt erkannt.
 *
 * @param  int results[] - Array, das nach R�ckkehr die IDs der Timeframes enth�lt, in denen das Event aufgetreten ist (mehrere sind m�glich)
 * @param  int flags     - Flags ein oder mehrerer zu pr�fender Timeframes (default: der aktuelle Timeframe)
 *
 * @return bool - ob mindestens ein BarOpen-Event aufgetreten ist
 *
 *
 * NOTE: Diese Implementierung stimmt mit der Implementierung in ""libraries\stdlib1.mq4"" f�r Indikatoren �berein.
 */
bool EventListener.BarOpen(int results[], int flags=NULL) {
   if (ArraySize(results) != 0)
      ArrayResize(results, 0);

   if (flags == NULL)
      flags = PeriodFlag(Period());

   /*                                                                // TODO: Listener f�r PERIOD_MN1 implementieren
   +--------------------------+--------------------------+
   | Aufruf bei erstem Tick   | Aufruf bei weiterem Tick |
   +--------------------------+--------------------------+
   | Tick.prevTime = 0;       | Tick.prevTime = time[1]; |           // time[] stellt hier nur eine Pseudovariable dar (existiert nicht)
   | Tick.Time     = time[0]; | Tick.Time     = time[0]; |
   +--------------------------+--------------------------+
   */
   static datetime bar.openTimes[], bar.closeTimes[];                // OpenTimes/-CloseTimes der Bars der jeweiligen Perioden

                                                                     // die am h�ufigsten verwendeten Perioden zuerst (beschleunigt Ausf�hrung)
   static int sizeOfPeriods, periods    []={  PERIOD_H1,   PERIOD_M30,   PERIOD_M15,   PERIOD_M5,   PERIOD_M1,   PERIOD_H4,   PERIOD_D1,   PERIOD_W1/*,   PERIOD_MN1*/},
                             periodFlags[]={F_PERIOD_H1, F_PERIOD_M30, F_PERIOD_M15, F_PERIOD_M5, F_PERIOD_M1, F_PERIOD_H4, F_PERIOD_D1, F_PERIOD_W1/*, F_PERIOD_MN1*/};
   if (sizeOfPeriods == 0) {
      sizeOfPeriods = ArraySize(periods);
      ArrayResize(bar.openTimes,  sizeOfPeriods);
      ArrayResize(bar.closeTimes, sizeOfPeriods);
   }

   int isEvent;

   for (int i=0; i < sizeOfPeriods; i++) {
      if (flags & periodFlags[i] != 0) {
         // BarOpen/Close-Time des aktuellen Ticks ggf. neuberechnen
         if (Tick.Time >= bar.closeTimes[i]) {                       // true sowohl bei Initialisierung als auch bei BarOpen
            bar.openTimes [i] = Tick.Time - Tick.Time % (periods[i]*MINUTES);
            bar.closeTimes[i] = bar.openTimes[i]      + (periods[i]*MINUTES);
         }

         // Event anhand des vorherigen Ticks bestimmen
         if (Tick.prevTime < bar.openTimes[i]) {
            if (!Tick.prevTime) {
               if (Expert.IsTesting())                               // im Tester ist der 1. Tick BarOpen-Event      TODO: !!! nicht f�r alle Timeframes !!!
                  isEvent = ArrayPushInt(results, periods[i]);
            }
            else {
               isEvent = ArrayPushInt(results, periods[i]);
            }
         }

         // Abbruch, wenn nur dieses einzelne Flag gepr�ft werden soll (die am h�ufigsten verwendeten Perioden sind zuerst angeordnet)
         if (flags == periodFlags[i])
            break;
      }
   }
   return(isEvent != 0);
}


/**
 * Setzt den internen Fehlercode des Moduls.
 *
 * @param  int error - Fehlercode
 *
 * @return int - derselbe Fehlercode (for chaining)
 *
 *
 * NOTE: Akzeptiert einen weiteren beliebigen Parameter, der bei der Verarbeitung jedoch ignoriert wird.
 */
int SetLastError(int error, int param=NULL) {
   last_error = error;

   switch (error) {
      case NO_ERROR              :
      case ERS_HISTORY_UPDATE    :
      case ERS_TERMINAL_NOT_READY:
      case ERS_EXECUTION_STOPPING: break;

      default:
         __STATUS_ERROR = true;
   }
   return(ec.setLastError(__ExecutionContext, last_error));
}


// -- init()-Templates ------------------------------------------------------------------------------------------------------------------------------


/**
 * Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int onInit() {
   return(NO_ERROR);
}


/**
 * Nach Parameter�nderung
 *
 *  - altes Chartfenster, alter EA, Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitParameterChange() {
   return(NO_ERROR);
}


/**
 * Nach Symbol- oder Timeframe-Wechsel
 *
 * - altes Chartfenster, alter EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitChartChange() {
   return(NO_ERROR);
}


/**
 * Nach Accountwechsel
 *
 * TODO: Umst�nde ungekl�rt, wird in stdlib mit ERR_RUNTIME_ERROR abgefangen
 *
 * @return int - Fehlerstatus
 *
int onInitAccountChange() {
   return(NO_ERROR);
}


/**
 * Altes Chartfenster mit neu geladenem Template
 *
 * - neuer EA, Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitChartClose() {
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt
 *
 * - nach Terminal-Neustart: neues Chartfenster, vorheriger EA, kein Input-Dialog
 * - nach File->New->Chart:  neues Chartfenster, neuer EA, Input-Dialog
 * - im Tester:              neues Chartfenster bei VisualMode=On, neuer EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitUndefined() {
   return(NO_ERROR);
}


/**
 * Vorheriger EA von Hand entfernt (Chart->Expert->Remove) oder neuer EA dr�bergeladen
 *
 * - altes Chartfenster, neuer EA, Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitRemove() {
   return(NO_ERROR);
}


/**
 * Nach Recompilation
 *
 * - altes Chartfenster, vorheriger EA, kein Input-Dialog
 *
 * @return int - Fehlerstatus
 *
int onInitRecompile() {
   return(NO_ERROR);
}


/**
 * Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int afterInit() {
   return(NO_ERROR);
}
 */


// -- deinit()-Templates ----------------------------------------------------------------------------------------------------------------------------


/**
 * Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int onDeinit() {
   double test.duration = (Test.stopMillis-Test.startMillis)/1000.0;
   double test.days     = (Test.toDate-Test.fromDate) * 1.0 /DAYS;
   debug("onDeinit()   time="+ DoubleToStr(test.duration, 1) +" sec   days="+ Round(test.days) +"   ("+ DoubleToStr(test.duration/test.days, 3) +" sec/day)");
   return(last_error);
}


/**
 * Parameter�nderung
 *
 * @return int - Fehlerstatus
 *
int onDeinitParameterChange() {
   return(NO_ERROR);
}


/**
 * Symbol- oder Timeframewechsel
 *
 * @return int - Fehlerstatus
 *
int onDeinitChartChange() {
   return(NO_ERROR);
}


/**
 * Accountwechsel
 *
 * TODO: Umst�nde ungekl�rt, wird in stdlib mit ERR_RUNTIME_ERROR abgefangen
 *
 * @return int - Fehlerstatus
 *
int onDeinitAccountChange() {
   return(NO_ERROR);
}


/**
 * Im Tester: - Nach Bet�tigen des "Stop"-Buttons oder nach Chart->Close. Der "Stop"-Button des Testers kann nach Fehler oder Testabschlu�
 *              vom Code "bet�tigt" worden sein.
 *
 * Online:    - Chart wird geschlossen                  - oder -
 *            - Template wird neu geladen               - oder -
 *            - Terminal-Shutdown                       - oder -
 *
 * @return int - Fehlerstatus
 *
int onDeinitChartClose() {
   return(NO_ERROR);
}


/**
 * Kein UninitializeReason gesetzt: nur im Tester nach regul�rem Ende (Testperiode zu Ende)
 *
 * @return int - Fehlerstatus
 *
int onDeinitUndefined() {
   return(NO_ERROR);
}


/**
 * Nur Online: EA von Hand entfernt (Chart->Expert->Remove) oder neuer EA dr�bergeladen
 *
 * @return int - Fehlerstatus
 *
int onDeinitRemove() {
   return(NO_ERROR);
}


/**
 * Recompilation
 *
 * @return int - Fehlerstatus
 *
int onDeinitRecompile() {
   return(NO_ERROR);
}


/**
 * Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int afterDeinit() {
   return(NO_ERROR);
}
 */
