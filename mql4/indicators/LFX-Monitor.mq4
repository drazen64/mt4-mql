/**
 * Berechnet die Kurse der momentan verf�gbaren LiteForex-Indizes und zeigt sie an.
 */
#include <stdlib.mqh>


#property indicator_chart_window


string fontName  = "Tahoma";
int    fontSize  = 10;
color  fontColor = Blue;
color  bgColor   = C'212,208,200';

string symbols[] = { "USDLFX","AUDLFX","CADLFX","CHFLFX","EURLFX","GBPLFX","JPYLFX" };
string labels[];

#define USDLFX  0
#define AUDLFX  1
#define CADLFX  2
#define CHFLFX  3
#define EURLFX  4
#define GBPLFX  5
#define JPYLFX  6


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   CreateLabels();
   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   RemoveChartObjects(labels);
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   if      (init_error != NO_ERROR)                   ValidBars = 0;
   else if (last_error == ERR_TERMINAL_NOT_YET_READY) ValidBars = 0;
   else if (last_error == ERR_HISTORY_UPDATE)         ValidBars = 0;
   else                                               ValidBars = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init_error == ERR_TERMINAL_NOT_YET_READY) /*&&*/ if (!init)
      init();
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);

   // nach Terminal-Start Abschlu� der Initialisierung �berpr�fen
   if (Bars == 0) {
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = 0;
   // -----------------------------------------------------------------------------


   last_error = UpdateInfos();

   return(catch("start()"));
}


/**
 *
 */
int CreateLabels() {
   string expertName = WindowExpertName();
   int c = 10;                               // Z�hlervariable f�r Label

   // Background
   c++;
   string label = StringConcatenate(expertName, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, 80);
      ObjectSet(label, OBJPROP_YDISTANCE, 70);
      ObjectSetText(label, "g", 92, "Webdings", bgColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   c++;
   label = StringConcatenate(expertName, ".", c, ".Background");
   if (ObjectFind(label) > -1)
      ObjectDelete(label);
   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(label, OBJPROP_XDISTANCE, 60);
      ObjectSet(label, OBJPROP_YDISTANCE, 70);
      ObjectSetText(label, "g", 92, "Webdings", bgColor);
      RegisterChartObject(label, labels);
   }
   else GetLastError();

   // Textlabel
   int yCoord = 74;
   for (int i=0; i < ArraySize(symbols); i++) {
      c++;
      label = StringConcatenate(expertName, ".", c, ".", StringLeft(symbols[i], 3));
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE,  166);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, StringLeft(symbols[i], 3) +":", fontSize, fontName, fontColor);
         RegisterChartObject(label, labels);
         symbols[i] = label;
      }
      else GetLastError();

      label = StringConcatenate(label, ".quote");
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE,  106);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ");
         RegisterChartObject(label, labels);
      }
      else GetLastError();

      label = StringConcatenate(label, ".spread");
      if (ObjectFind(label) > -1)
         ObjectDelete(label);
      if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(label, OBJPROP_CORNER, CORNER_TOP_RIGHT);
         ObjectSet(label, OBJPROP_XDISTANCE,  66);
         ObjectSet(label, OBJPROP_YDISTANCE, yCoord + i*16);
         ObjectSetText(label, " ");
         RegisterChartObject(label, labels);
      }
      else GetLastError();
   }

   return(catch("CreateLabels()"));
}


/**
 *
 * @return int - Fehlerstatus
 */
int UpdateInfos() {
   double usdlfx, usdlfx_Bid, usdlfx_Ask;
   double audlfx, audlfx_Bid, audlfx_Ask;
   double cadlfx, cadlfx_Bid, cadlfx_Ask;
   double chflfx, chflfx_Bid, chflfx_Ask;
   double eurlfx, eurlfx_Bid, eurlfx_Ask;
   double gbplfx, gbplfx_Bid, gbplfx_Ask;
   double jpylfx, jpylfx_Bid, jpylfx_Ask;

   // USDLFX
   double usdcad_Bid = MarketInfo("USDCAD", MODE_BID), usdcad_Ask = MarketInfo("USDCAD", MODE_ASK), usdcad = (usdcad_Bid + usdcad_Ask)/2;
   double usdchf_Bid = MarketInfo("USDCHF", MODE_BID), usdchf_Ask = MarketInfo("USDCHF", MODE_ASK), usdchf = (usdchf_Bid + usdchf_Ask)/2;
   double usdjpy_Bid = MarketInfo("USDJPY", MODE_BID), usdjpy_Ask = MarketInfo("USDJPY", MODE_ASK), usdjpy = (usdjpy_Bid + usdjpy_Ask)/2;
   double audusd_Bid = MarketInfo("AUDUSD", MODE_BID), audusd_Ask = MarketInfo("AUDUSD", MODE_ASK), audusd = (audusd_Bid + audusd_Ask)/2;
   double eurusd_Bid = MarketInfo("EURUSD", MODE_BID), eurusd_Ask = MarketInfo("EURUSD", MODE_ASK), eurusd = (eurusd_Bid + eurusd_Ask)/2;
   double gbpusd_Bid = MarketInfo("GBPUSD", MODE_BID), gbpusd_Ask = MarketInfo("GBPUSD", MODE_ASK), gbpusd = (gbpusd_Bid + gbpusd_Ask)/2;
   bool usd = (usdcad_Bid>0 && usdchf_Bid>0 && usdjpy_Bid>0 && audusd_Bid>0 && eurusd_Bid>0 && gbpusd_Bid>0);
   if (usd) {
      usdlfx     = MathPow((usdcad     * usdchf     * usdjpy    ) / (audusd     * eurusd     * gbpusd    ), 1/7.0);
      usdlfx_Bid = MathPow((usdcad_Bid * usdchf_Bid * usdjpy_Bid) / (audusd_Ask * eurusd_Ask * gbpusd_Ask), 1/7.0);
      usdlfx_Ask = MathPow((usdcad_Ask * usdchf_Ask * usdjpy_Ask) / (audusd_Bid * eurusd_Bid * gbpusd_Bid), 1/7.0);
   }

   // AUDLFX
   double audcad_Bid = MarketInfo("AUDCAD", MODE_BID), audcad_Ask = MarketInfo("AUDCAD", MODE_ASK), audcad = (audcad_Bid + audcad_Ask)/2;
   double audchf_Bid = MarketInfo("AUDCHF", MODE_BID), audchf_Ask = MarketInfo("AUDCHF", MODE_ASK), audchf = (audchf_Bid + audchf_Ask)/2;
   double audjpy_Bid = MarketInfo("AUDJPY", MODE_BID), audjpy_Ask = MarketInfo("AUDJPY", MODE_ASK), audjpy = (audjpy_Bid + audjpy_Ask)/2;
   //     audusd_Bid = ...
   double euraud_Bid = MarketInfo("EURAUD", MODE_BID), euraud_Ask = MarketInfo("EURAUD", MODE_ASK), euraud = (euraud_Bid + euraud_Ask)/2;
   double gbpaud_Bid = MarketInfo("GBPAUD", MODE_BID), gbpaud_Ask = MarketInfo("GBPAUD", MODE_ASK), gbpaud = (gbpaud_Bid + gbpaud_Ask)/2;
   bool aud = (audcad_Bid>0 && audchf_Bid>0 && audjpy_Bid>0 && audusd_Bid>0 && euraud_Bid>0 && gbpaud_Bid>0);
   if (usd)
      audlfx     = usdlfx * audusd;
   if (aud) {
      if (!usd)
         audlfx  = MathPow((audcad     * audchf     * audjpy     * audusd    ) / (euraud     * gbpaud    ), 1/7.0);
      audlfx_Bid = MathPow((audcad_Bid * audchf_Bid * audjpy_Bid * audusd_Bid) / (euraud_Ask * gbpaud_Ask), 1/7.0);
      audlfx_Ask = MathPow((audcad_Ask * audchf_Ask * audjpy_Ask * audusd_Ask) / (euraud_Bid * gbpaud_Bid), 1/7.0);
   }

   // CADLFX
   double cadchf_Bid = MarketInfo("CADCHF", MODE_BID), cadchf_Ask = MarketInfo("CADCHF", MODE_ASK), cadchf = (cadchf_Bid + cadchf_Ask)/2;
   double cadjpy_Bid = MarketInfo("CADJPY", MODE_BID), cadjpy_Ask = MarketInfo("CADJPY", MODE_ASK), cadjpy = (cadjpy_Bid + cadjpy_Ask)/2;
   //     audcad_Bid = ...
   double eurcad_Bid = MarketInfo("EURCAD", MODE_BID), eurcad_Ask = MarketInfo("EURCAD", MODE_ASK), eurcad = (eurcad_Bid + eurcad_Ask)/2;
   double gbpcad_Bid = MarketInfo("GBPCAD", MODE_BID), gbpcad_Ask = MarketInfo("GBPCAD", MODE_ASK), gbpcad = (gbpcad_Bid + gbpcad_Ask)/2;
   //     usdcad_Bid = ...
   bool cad = (cadchf_Bid>0 && cadjpy_Bid>0 && audcad_Bid>0 && eurcad_Bid>0 && gbpcad_Bid>0 && usdcad_Bid>0);
   if (usd)
      cadlfx     = usdlfx / usdcad;
   if (cad) {
      if (!usd)
         cadlfx  = MathPow((cadchf     * cadjpy    ) / (audcad     * eurcad     * gbpcad     * usdcad    ), 1/7.0);
      cadlfx_Bid = MathPow((cadchf_Bid * cadjpy_Bid) / (audcad_Ask * eurcad_Ask * gbpcad_Ask * usdcad_Ask), 1/7.0);
      cadlfx_Ask = MathPow((cadchf_Ask * cadjpy_Ask) / (audcad_Bid * eurcad_Bid * gbpcad_Bid * usdcad_Bid), 1/7.0);
   }

   // CHFLFX
   double chfjpy_Bid = MarketInfo("CHFJPY", MODE_BID), chfjpy_Ask = MarketInfo("CHFJPY", MODE_ASK), chfjpy = (chfjpy_Bid + chfjpy_Ask)/2;
   //     audchf_Bid = ...
   //     cadchf_Bid = ...
   double eurchf_Bid = MarketInfo("EURCHF", MODE_BID), eurchf_Ask = MarketInfo("EURCHF", MODE_ASK), eurchf = (eurchf_Bid + eurchf_Ask)/2;
   double gbpchf_Bid = MarketInfo("GBPCHF", MODE_BID), gbpchf_Ask = MarketInfo("GBPCHF", MODE_ASK), gbpchf = (gbpchf_Bid + gbpchf_Ask)/2;
   //     usdchf_Bid = ...
   bool chf = (chfjpy_Bid>0 && audchf_Bid>0 && cadchf_Bid>0 && eurchf_Bid>0 && gbpchf_Bid>0 && usdchf_Bid>0);
   if (usd)
      chflfx     = usdlfx / usdchf;
   if (chf) {
      if (!usd)
         chflfx  = MathPow(chfjpy     / (audchf     * cadchf     * eurchf     * gbpchf     * usdchf    ), 1/7.0);
      chflfx_Bid = MathPow(chfjpy_Bid / (audchf_Ask * cadchf_Ask * eurchf_Ask * gbpchf_Ask * usdchf_Ask), 1/7.0);
      chflfx_Ask = MathPow(chfjpy_Ask / (audchf_Bid * cadchf_Bid * eurchf_Bid * gbpchf_Bid * usdchf_Bid), 1/7.0);
   }

   // EURLFX
   //     euraud_Bid = ...
   //     eurcad_Bid = ...
   //     eurchf_Bid = ...
   double eurgbp_Bid = MarketInfo("EURGBP", MODE_BID), eurgbp_Ask = MarketInfo("EURGBP", MODE_ASK), eurgbp = (eurgbp_Bid + eurgbp_Ask)/2;
   double eurjpy_Bid = MarketInfo("EURJPY", MODE_BID), eurjpy_Ask = MarketInfo("EURJPY", MODE_ASK), eurjpy = (eurjpy_Bid + eurjpy_Ask)/2;
   //     eurusd_Bid = ...
   bool eur = (euraud_Bid>0 && eurcad_Bid>0 && eurchf_Bid>0 && eurgbp_Bid>0 && eurjpy_Bid>0 && eurusd_Bid>0);
   if (usd)
      eurlfx     = usdlfx * eurusd;
   if (eur) {
      if (!usd)
         eurlfx  = MathPow((euraud     * eurcad     * eurchf     * eurgbp     * eurjpy     * eurusd    ), 1/7.0);
      eurlfx_Bid = MathPow((euraud_Bid * eurcad_Bid * eurchf_Bid * eurgbp_Bid * eurjpy_Bid * eurusd_Bid), 1/7.0);
      eurlfx_Ask = MathPow((euraud_Ask * eurcad_Ask * eurchf_Ask * eurgbp_Ask * eurjpy_Ask * eurusd_Ask), 1/7.0);
   }

   // GBPLFX
   //     gbpaud_Bid = ...
   //     gbpcad_Bid = ...
   //     gbpchf_Bid = ...
   double gbpjpy_Bid = MarketInfo("GBPJPY", MODE_BID), gbpjpy_Ask = MarketInfo("GBPJPY", MODE_ASK), gbpjpy = (gbpjpy_Bid + gbpjpy_Ask)/2;
   //     gbpusd_Bid = ...
   //     eurgbp_Bid = ...
   bool gbp = (gbpaud_Bid>0 && gbpcad_Bid>0 && gbpchf_Bid>0 && gbpjpy_Bid>0 && gbpusd_Bid>0 && eurgbp_Bid>0);
   if (usd)
      gbplfx     = usdlfx * gbpusd;
   if (gbp) {
      if (!usd)
         gbplfx  = MathPow((gbpaud     * gbpcad     * gbpchf     * gbpjpy     * gbpusd    ) / eurgbp    , 1/7.0);
      gbplfx_Bid = MathPow((gbpaud_Bid * gbpcad_Bid * gbpchf_Bid * gbpjpy_Bid * gbpusd_Bid) / eurgbp_Ask, 1/7.0);
      gbplfx_Ask = MathPow((gbpaud_Ask * gbpcad_Ask * gbpchf_Ask * gbpjpy_Ask * gbpusd_Ask) / eurgbp_Bid, 1/7.0);
   }

   // JPYLFX
   //     audjpy_Bid = ...
   //     cadjpy_Bid = ...
   //     chfjpy_Bid = ...
   //     eurjpy_Bid = ...
   //     gbpjpy_Bid = ...
   //     usdjpy_Bid = ...
   bool jpy = (audjpy_Bid>0 && cadjpy_Bid>0 && chfjpy_Bid>0 && eurjpy_Bid>0 && gbpjpy_Bid>0 && usdjpy_Bid>0);
   if (usd)
      jpylfx     = usdjpy / usdlfx;
   if (jpy) {
      if (!usd)
         jpylfx  = MathPow((audjpy     * cadjpy     * chfjpy     * eurjpy     * gbpjpy     * usdjpy    ), 1/7.0);
      jpylfx_Bid = MathPow((audjpy_Bid * cadjpy_Bid * chfjpy_Bid * eurjpy_Bid * gbpjpy_Bid * usdjpy_Bid), 1/7.0);
      jpylfx_Ask = MathPow((audjpy_Ask * cadjpy_Ask * chfjpy_Ask * eurjpy_Ask * gbpjpy_Ask * usdjpy_Ask), 1/7.0);
   }

   int error = GetLastError();
   if (error == ERR_HISTORY_UPDATE)
      return(error);
   if (error != NO_ERROR && error != ERR_UNKNOWN_SYMBOL)
      return(catch("UpdateInfos(1)", error));


   // Index-Anzeige
   if (usdlfx     > 0) ObjectSetText(symbols[USDLFX] +".quote", NumberToStr(NormalizeDouble(usdlfx, 5), ".4'"), fontSize, fontName, fontColor);
   if (audlfx     > 0) ObjectSetText(symbols[AUDLFX] +".quote", NumberToStr(NormalizeDouble(audlfx, 5), ".4'"), fontSize, fontName, fontColor);
   if (cadlfx     > 0) ObjectSetText(symbols[CADLFX] +".quote", NumberToStr(NormalizeDouble(cadlfx, 5), ".4'"), fontSize, fontName, fontColor);
   if (chflfx     > 0) ObjectSetText(symbols[CHFLFX] +".quote", NumberToStr(NormalizeDouble(chflfx, 5), ".4'"), fontSize, fontName, fontColor);
   if (eurlfx     > 0) ObjectSetText(symbols[EURLFX] +".quote", NumberToStr(NormalizeDouble(eurlfx, 5), ".4'"), fontSize, fontName, fontColor);
   if (gbplfx     > 0) ObjectSetText(symbols[GBPLFX] +".quote", NumberToStr(NormalizeDouble(gbplfx, 5), ".4'"), fontSize, fontName, fontColor);
   if (jpylfx     > 0) ObjectSetText(symbols[JPYLFX] +".quote", NumberToStr(NormalizeDouble(jpylfx, 3), ".2'"), fontSize, fontName, fontColor);

   // Spread-Anzeige
   if (usdlfx_Bid > 0) ObjectSetText(symbols[USDLFX] +".quote.spread", StringConcatenate("(", NumberToStr(NormalizeDouble((usdlfx_Ask-usdlfx_Bid)*10000, 1), ".1"), ")"), fontSize, fontName, fontColor);
   if (audlfx_Bid > 0) ObjectSetText(symbols[AUDLFX] +".quote.spread", StringConcatenate("(", NumberToStr(NormalizeDouble((audlfx_Ask-audlfx_Bid)*10000, 1), ".1"), ")"), fontSize, fontName, fontColor);
   if (cadlfx_Bid > 0) ObjectSetText(symbols[CADLFX] +".quote.spread", StringConcatenate("(", NumberToStr(NormalizeDouble((cadlfx_Ask-cadlfx_Bid)*10000, 1), ".1"), ")"), fontSize, fontName, fontColor);
   if (chflfx_Bid > 0) ObjectSetText(symbols[CHFLFX] +".quote.spread", StringConcatenate("(", NumberToStr(NormalizeDouble((chflfx_Ask-chflfx_Bid)*10000, 1), ".1"), ")"), fontSize, fontName, fontColor);
   if (eurlfx_Bid > 0) ObjectSetText(symbols[EURLFX] +".quote.spread", StringConcatenate("(", NumberToStr(NormalizeDouble((eurlfx_Ask-eurlfx_Bid)*10000, 1), ".1"), ")"), fontSize, fontName, fontColor);
   if (gbplfx_Bid > 0) ObjectSetText(symbols[GBPLFX] +".quote.spread", StringConcatenate("(", NumberToStr(NormalizeDouble((gbplfx_Ask-gbplfx_Bid)*10000, 1), ".1"), ")"), fontSize, fontName, fontColor);
   if (jpylfx_Bid > 0) ObjectSetText(symbols[JPYLFX] +".quote.spread", StringConcatenate("(", NumberToStr(NormalizeDouble((jpylfx_Ask-jpylfx_Bid)*  100, 1), ".1"), ")"), fontSize, fontName, fontColor);

   return(catch("UpdateInfos(2)"));
}
