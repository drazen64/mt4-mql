//+------------------------------------------------------------------+
//|                                               Moving Average.mq4 |
//|                      Copyright � 2005, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "(original)"                                        // pewa: reformatted and final error check added


#define MAGICMA  20050610


extern double Lotsize        =  0.1;                                    // wird ignoriert
extern double MaximumRisk    =  0.02;
extern double DecreaseFactor =  3.0;
extern double MovingPeriod   = 12.0;
extern double MovingShift    =  6.0;


/**
 * Calculate open positions
 */
int CalculateCurrentOrders(string symbol) {
   int buys=0, sells=0;

   for (int i=0; i<OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;
      if (OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA) {
         if (OrderType() == OP_BUY ) buys++;
         if (OrderType() == OP_SELL) sells++;
      }
   }
   // return orders volume
   if (buys > 0) return(  buys);
   else          return(-sells);
}


/**
 * Calculate optimal lot size
 */
double LotsOptimized() {
   double lot = Lotsize;                                             // Lotsize wird ignoriert
   // select lot size                                                // compounding money management (da neue Trades erst nach Schlie�en einer offenen Position
   lot = NormalizeDouble(AccountFreeMargin() * MaximumRisk/1000, 1); // ge�ffnet werden, kann AccountFreeMargin() durch AccountBalance() ersetzt werden)

   // calculate number of consecutive losses
   if (DecreaseFactor > 0) {
   	int orders = HistoryTotal();
      int losses = 0;                                                // number of consecutive losses

      for (int i=orders-1; i>=0; i--) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
            Print("Error in history!");
            break;
         }
         if (OrderSymbol()!=Symbol() || OrderType()>OP_SELL)         // MagicNumber wird ignoriert
            continue;
         if (OrderProfit() > 0) break;
         if (OrderProfit() < 0) losses++;
      }
      if (losses > 1)                                                // Bl�dsinn: Der erste Verlust hat keine Wirkung, bei DecreaseFactor=3 reduziert der zweite
         lot = NormalizeDouble(lot - losses/DecreaseFactor*lot, 1);  // Verlust die Lotsize um 66% und folgende Verluste haben ebenfalls keine Wirkung.
   }

   // return lot size
   if (lot < 0.1)
      lot = 0.1;
   return(lot);
}


/**
 * Check for open order conditions
 */
void CheckForOpen() {
   double ma;
   int res;

   // trade only at first tick of new bar
   if (Volume[0] > 1)
      return;

   // Simple Moving Average of Bar[MA.Shift]                                                          // MA[0] mit MA.Shift entspricht MA[Shift] bei Shift=0.
   ma = iMA(NULL, 0, MovingPeriod, MovingShift, MODE_SMA, PRICE_CLOSE, 0);                            // Mit einem SMA(12) liegt jede Bar zumindest in der N�he des
                                                                                                      // MA, die Entry-Signale sind also praktisch zuf�llig.
   // sell conditions
   // Bl�dsinn: Short-Signal, wenn die letzte Bar bearish war und MA[6] innerhalb ihres Bodies liegt.
   if (Open[1] > ma && Close[1] < ma) {
      res = OrderSend(Symbol(), OP_SELL, LotsOptimized(), Bid, 3, 0, 0, "", MAGICMA, 0, Red);
      return;
   }

   // buy conditions
   // Bl�dsinn: Long-Signal, wenn kein Short-Signal, die letzte Bar bullish war und MA[6] innerhalb ihres Bodies liegt.
   if (Open[1] < ma && Close[1] > ma) {
      res = OrderSend(Symbol(), OP_BUY, LotsOptimized(), Ask, 3, 0, 0, "", MAGICMA, 0, Blue);
      return;
   }
}


/**
 * Check for close order conditions                                        // Da es keinen TakeProfit gibt und der fast zuf�llige Exit in der N�he des Entries
 *                                                                         // wie ein kleiner StopLoss wirkt, provoziert die Strategie viele kleine Verluste.
 * Es ist maximal eine Position (Long oder Short) offen.                   // Sie verh�lt sich �hnlich einer umgedrehten Scalping-Strategie, entsprechend verursachen
 */                                                                        // Slippage, Spread und Geb�hren massive Schwankungen (in diesem Fall beim Verlust).
void CheckForClose() {
   double ma;

   // trade only at first tick of new bar
   if (Volume[0] > 1)
      return;

   // Simple Moving Average of MA[Shift]
   ma = iMA(NULL, 0, MovingPeriod, MovingShift, MODE_SMA, PRICE_CLOSE, 0);

   for (int i=0; i<OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;
      if (OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol())
         continue;

      // check order type                                                  // Bl�dsinn analog zum Entry-Signal
      if (OrderType() == OP_BUY) {
         if (Open[1] > ma && Close[1] < ma)
            OrderClose(OrderTicket(), OrderLots(), Bid, 3, White);         // Exit-Long, wenn die letzte Bar bearisch war und MA[Shift] innerhalb ihres Bodies liegt.
         break;
      }
      if (OrderType() == OP_SELL) {
         if (Open[1] < ma && Close[1] > ma)
            OrderClose(OrderTicket(), OrderLots(), Ask, 3, White);         // Exit-Short, wenn die letzte Bar bullish war und MA[Shift] innerhalb ihres Bodies liegt.
         break;
      }
   }
}


/**
 * Start function
 */
void start() {
   // check for history and trading
   if (Bars < 100 || !IsTradeAllowed()) {
      CheckError("start(1)");
      return;
   }

   // calculate open orders by current symbol
   if (CalculateCurrentOrders(Symbol()) == 0) CheckForOpen();
   else                                       CheckForClose();

   CheckError("start(2)");
}


/**
 * pewa: error check and one single alert at the first error
 */
void CheckError(string location) {
   int error = GetLastError();
   if (error != 0) {
      static bool alerted = false;
      if (!alerted) {
         Alert(WindowExpertName() +"::"+ location +"  error="+ error);
         alerted = true;
      }
   }
}
