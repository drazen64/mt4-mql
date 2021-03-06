/**
 * EA-Display Start-Stop
 *
 * Schickt dem Expert des aktuellen Charts das Kommando, den Modus der Start/Stop-Anzeige zu wechseln.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#include <SnowRoller/define.mqh>
#include <SnowRoller/functions.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string ids[], label, mutex="mutex.ChartCommand";
   int status[], sizeOfIds;


   // (1) Sequenzen des aktuellen Charts ermitteln
   if (FindChartSequences(ids, status)) {
      sizeOfIds = ArraySize(ids);


      // (2) f�r Command unzutreffende Sequenzen herausfiltern
      for (int i=sizeOfIds-1; i >= 0; i--) {
         switch (status[i]) {
          //case STATUS_UNINITIALIZED:    //
            case STATUS_WAITING      :    // ok
            case STATUS_STARTING     :    // ok
            case STATUS_PROGRESSING  :    // ok
            case STATUS_STOPPING     :    // ok
            case STATUS_STOPPED      :    // ok
               continue;
            default:
               ArraySpliceStrings(ids, i, 1);
               ArraySpliceInts(status, i, 1);
               sizeOfIds--;
         }
      }


      // (3) Command setzen
      if (!AquireLock(mutex, true))
         return(ERR_RUNTIME_ERROR);

      for (i=0; i < sizeOfIds; i++) {
         label = StringConcatenate("SnowRoller.", ids[i], ".command");           // TODO: Commands zu bereits existierenden Commands hinzuf�gen
         if (ObjectFind(label) != 0) {
            if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
               return(_int(catch("onStart(1)"), ReleaseLock(mutex)));
            ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
         }
         ObjectSetText(label, "startstopdisplay", 1);
      }

      if (!ReleaseLock(mutex))
         return(ERR_RUNTIME_ERROR);


      // (4) Tick senden
      Chart.SendTick();
      return(catch("onStart(2)"));                                               // regular exit
   }

   if (!last_error) {
      if (sizeOfIds == 0) {
         PlaySoundEx("chord.wav");
         ForceMessageBox(__NAME__, "No sequence found.", MB_ICONEXCLAMATION|MB_OK);
      }
      catch("onStart(3)");
   }
   return(last_error);
}


/**
 * Unterdr�ckt unn�tze Compilerwarnungen.
 */
void DummyCalls() {
   ConfirmTick1Trade(NULL, NULL);
   CreateEventId();
   CreateSequenceId();
   IsSequenceStatus(NULL);
   IsStopTriggered(NULL, NULL);
   StatusToStr(NULL);
}
