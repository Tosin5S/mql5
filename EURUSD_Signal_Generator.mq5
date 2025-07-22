//+------------------------------------------------------------------+
//|                                       EURUSD_Signal_Generator.mq5|
//|                                 
//|          
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      
#property version   "1.00"
#property description "A simple EUR/USD signal generator based on Moving Average crossover."

//--- Include the Trade library for future use (good practice)
#include <Trade\Trade.mqh>

//--- EA Input Parameters
// These are settings you can change from the EA's properties window in MetaTrader 5
input int    fast_ma_period = 10;      // Period for the Fast Moving Average
input int    slow_ma_period = 30;      // Period for the Slow Moving Average
input ENUM_MA_METHOD ma_method = MODE_EMA; // MA method (Exponential by default)
input ENUM_APPLIED_PRICE applied_price = PRICE_CLOSE; // Price to apply MA to

//--- Global variables
int fast_ma_handle; // Handle for the fast MA indicator
int slow_ma_handle; // Handle for the slow MA indicator

//--- Signal enumeration
enum ENUM_SIGNAL
  {
   SIGNAL_NONE, // No signal
   SIGNAL_BUY,  // Buy signal
   SIGNAL_SELL  // Sell signal
  };

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//| This runs once when the EA is first attached to the chart.       |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Check if the periods are logical
   if(fast_ma_period >= slow_ma_period)
     {
      Print("Error: Fast MA period must be less than Slow MA period.");
      return(INIT_FAILED);
     }

   //--- Create the moving average indicators
   // We create them here so we don't have to recreate them on every tick.
   fast_ma_handle = iMA(_Symbol, _Period, fast_ma_period, 0, ma_method, applied_price);
   slow_ma_handle = iMA(_Symbol, _Period, slow_ma_period, 0, ma_method, applied_price);

   //--- Check if the indicators were created successfully
   if(fast_ma_handle == INVALID_HANDLE || slow_ma_handle == INVALID_HANDLE)
     {
      Print("Error creating Moving Average indicators - ", GetLastError());
      return(INIT_FAILED);
     }

   //--- Initialization successful
   Print("EURUSD_Signal_Generator initialized successfully.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//| This runs when the EA is removed from the chart.                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Release the indicator handles to free up memory
   IndicatorRelease(fast_ma_handle);
   IndicatorRelease(slow_ma_handle);
   
   //--- Clear the chart comment
   Comment("");

   Print("EURUSD_Signal_Generator removed.");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//| This runs on every new price tick for the chart's symbol.        |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Get the current signal
   ENUM_SIGNAL current_signal = CheckForSignal();

   //--- Display the signal on the chart
   DisplaySignal(current_signal);
  }

//+------------------------------------------------------------------+
//| Checks for a trading signal based on MA crossover.               |
//+------------------------------------------------------------------+
ENUM_SIGNAL CheckForSignal()
  {
   //--- Arrays to hold the moving average values
   double fast_ma_buffer[3];
   double slow_ma_buffer[3];

   //--- Get the last 3 values of the moving averages
   // We need data for the previous bar (index 1) and the one before that (index 2)
   // to detect a crossover event.
   if(CopyBuffer(fast_ma_handle, 0, 0, 3, fast_ma_buffer) <= 0 ||
      CopyBuffer(slow_ma_handle, 0, 0, 3, slow_ma_buffer) <= 0)
     {
      Print("Error copying indicator buffers - ", GetLastError());
      return(SIGNAL_NONE);
     }
     
   //--- Reverse the arrays to have the most recent data at the beginning (easier to read)
   ArraySetAsSeries(fast_ma_buffer, true);
   ArraySetAsSeries(slow_ma_buffer, true);

   //--- Define the values for easier reading
   double fast_ma_previous = fast_ma_buffer[1];
   double slow_ma_previous = slow_ma_buffer[1];
   double fast_ma_historic = fast_ma_buffer[2];
   double slow_ma_historic = slow_ma_buffer[2];

   //--- Check for a BUY signal (Bullish Crossover)
   // The fast MA was below the slow MA on the historic bar, and is now above on the previous bar.
   if(fast_ma_historic < slow_ma_historic && fast_ma_previous > slow_ma_previous)
     {
      return(SIGNAL_BUY);
     }

   //--- Check for a SELL signal (Bearish Crossover)
   // The fast MA was above the slow MA on the historic bar, and is now below on the previous bar.
   if(fast_ma_historic > slow_ma_historic && fast_ma_previous < slow_ma_previous)
     {
      return(SIGNAL_SELL);
     }

   //--- If no crossover occurred, there is no signal
   return(SIGNAL_NONE);
  }

//+------------------------------------------------------------------+
//| Displays the current signal on the chart.                        |
//+------------------------------------------------------------------+
void DisplaySignal(ENUM_SIGNAL signal)
  {
   string signal_text = "WAIT";
   color  signal_color = clrGray;

   switch(signal)
     {
      case SIGNAL_BUY:
         signal_text = "BUY";
         signal_color = clrDodgerBlue;
         break;
      case SIGNAL_SELL:
         signal_text = "SELL";
         signal_color = clrOrangeRed;
         break;
      default:
         break;
     }

   //--- Create the comment string to display on the chart
   string comment_string = "EUR/USD Signal: " + signal_text;
   
   //--- Display the signal on the chart
   Comment(comment_string);
   
   //--- You could also add other information to the chart
   // string full_comment = StringFormat("--- EUR/USD Signal Generator ---\nSignal: %s\nFast MA: %s\nSlow MA: %s",
   //                                     signal_text,
   //                                     DoubleToString(fast_ma_buffer[1], _Digits),
   //                                     DoubleToString(slow_ma_buffer[1], _Digits));
   // Comment(full_comment);
  }
//+------------------------------------------------------------------+

