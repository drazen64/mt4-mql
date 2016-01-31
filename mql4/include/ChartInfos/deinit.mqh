/**
 * Deinitialisierung Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   // ggf. OfflineTicker deinstallieren
   if (tickTimerId > NULL) {
      int id = tickTimerId; tickTimerId = NULL;
      if (!RemoveTickTimer(id)) return(catch("onDeinit(1)->RemoveTickTimer(timerId="+ id +") failed", ERR_RUNTIME_ERROR));
   }

   // in allen deinit()-Szenarien Laufzeitstatus speichern
   if (!StoreRuntimeStatus()) return(last_error);

   DeleteRegisteredObjects(NULL);
   QC.StopChannels();
   QC.StopScriptParameterSender();
   return(last_error);
}


/**
 * außerhalb iCustom(): bei Parameteränderung
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitParameterChange() {
   // LFX-Orders in Library zwischenspeichern, um in init() das Neuladen zu sparen
   if (ChartInfos.CopyLfxOrders(true, lfxOrders, lfxOrders.iCache, lfxOrders.dCache) == -1)
      return(SetLastError(ERR_RUNTIME_ERROR));
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): bei Symbol- oder Timeframewechsel
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitChartChange() {
   // LFX-Orders in Library zwischenspeichern, um in init() das Neuladen zu sparen
   if (ChartInfos.CopyLfxOrders(true, lfxOrders, lfxOrders.iCache, lfxOrders.dCache) == -1)
      return(SetLastError(ERR_RUNTIME_ERROR));
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): Indikator von Hand entfernt oder Chart geschlossen, auch vorm Laden eines Profils oder Templates
 * innerhalb iCustom(): in allen deinit()-Fällen
 *
 * @return int - Fehlerstatus
 */
int onDeinitRemove() {
   // Profilwechsel oder Terminal-Shutdown

   // gecachte LFX-Orderdaten speichern
   if (!SaveLfxOrderCache())
      return(last_error);
   return(NO_ERROR);
}


/**
 * außerhalb iCustom(): bei Recompilation
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitRecompile() {
   // gecachte LFX-Orderdaten speichern
   if (!SaveLfxOrderCache())
      return(last_error);
   return(NO_ERROR);
}
