/**
 * Deinitialisierung Preprocessing-Hook
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   QC.StopChannels();
   return(last_error);
}


/**
 * außerhalb iCustom(): bei Parameteränderung
 * innerhalb iCustom(): nie
 *
 * @return int - Fehlerstatus
 */
int onDeinitParameterChange() {
   string symbol[1]; symbol[0] = Symbol();

   // LFX-Status in Library zwischenspeichern, um in init() Neuladen zu vermeiden
   if (ChartInfos.CopyLfxStatus(true, symbol, lfxOrders, lfxOrders.iVolatile, lfxOrders.dVolatile) == -1)
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
   string symbol[1]; symbol[0] = Symbol();

   // LFX-Status in Library zwischenspeichern, um in init() Neuladen zu vermeiden
   if (ChartInfos.CopyLfxStatus(true, symbol, lfxOrders, lfxOrders.iVolatile, lfxOrders.dVolatile) == -1)
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
   // volatilen LFX-Status in globalen Variablen speichern
   if (!SaveVolatileLfxStatus())
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
   // volatilen LFX-Status in globalen Variablen speichern
   if (!SaveVolatileLfxStatus())
      return(last_error);
   return(NO_ERROR);
}


/**
 * Deinitialisierung Postprocessing-Hook
 *
 * @return int - Fehlerstatus
 *
int afterDeinit() {
   return(NO_ERROR);
}
*/
