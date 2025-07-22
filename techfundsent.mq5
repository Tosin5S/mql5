//+------------------------------------------------------------------+
//|                                     Advanced_Signal_Generator.mq5|
//|                                     101S                         |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "101S"
#property link      "https://www.example.com"
#property version   "1.00"
#property description "An advanced signal generator for EURUSD combining Technical, Fundamental, and Sentimental analysis."

//--- Technical Analysis Inputs
input int    fast_ma_period = 12;      // MACD Fast EMA period
input int    slow_ma_period = 26;      // MACD Slow EMA period
input int    signal_ma_period = 9;       // MACD Signal Line SMA period
input int    trend_ma_period = 200;     // Period for the main Trend Filter MA
input int    rsi_period = 14;         // RSI Period
input int    rsi_overbought = 70;      // RSI Overbought level
input int    rsi_oversold = 30;        // RSI Oversold level

//--- Sentimental Analysis (Volatility) Inputs
input int    atr_period = 14;         // ATR period for volatility filter
input double atr_min_threshold = 0.0005; // Minimum ATR value to consider a signal (adjust for EURUSD)

//--- Fundamental Analysis (News) Inputs
input int    minutes_before_news = 120; // Avoid signals X minutes before high-impact news
input int    minutes_after_news = 120;  // Avoid signals X minutes after high-impact news

//--- Global Handles for Indicators
int macd_handle;
int trend_ma_handle;
int rsi_handle;
int atr_handle;

//--- Structure to hold news event data
struct NewsEvent
  {
   datetime time;
   string   currency;
   string   impact;
  };
NewsEvent upcoming_events[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Initialize Technical Indicators
   macd_handle = iMACD(_Symbol, _Period, fast_ma_period, slow_ma_period, signal_ma_period, PRICE_CLOSE);
   trend_ma_handle = iMA(_Symbol, _Period, trend_ma_period, 0, MODE_EMA, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, _Period, rsi_period, PRICE_CLOSE);
   atr_handle = iATR(_Symbol, _Period, atr_period);

   if(macd_handle == INVALID_HANDLE || trend_ma_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE)
     {
      Print("Error creating technical indicators - ", GetLastError());
      return(INIT_FAILED);
     }
     
   //--- Allow web requests for the news filter
   //--- You must also enable this in the terminal settings: Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL
   WebRequest("GET", "https://nfs.forexfactory.net/ff_calendar_thisweek.xml", "", NULL, 5000, NULL, 0, NULL, 0);
   Print("EA Initialized. Remember to allow WebRequest to 'https://nfs.forexfactory.net' in your terminal options.");
   
   //--- Fetch news for the first time
   FetchNewsData();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Release indicator handles
   IndicatorRelease(macd_handle);
   IndicatorRelease(trend_ma_handle);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(atr_handle);
   
   Comment("");
   Print("Advanced Signal Generator removed.");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Static variables to prevent checking on every single tick
   static datetime last_check_time = 0;
   static datetime last_news_fetch = 0;

   //--- Only run the logic once per minute to save resources
   if(TimeCurrent() - last_check_time < 60)
      return;
   last_check_time = TimeCurrent();
   
   //--- Fetch news data once every 4 hours
   if(TimeCurrent() - last_news_fetch > 4 * 3600)
     {
      FetchNewsData();
      last_news_fetch = TimeCurrent();
     }

   //--- Step 1: Fundamental Analysis - Check for news
   if(IsNearHighImpactNews())
     {
      Comment("Signal: WAIT (High-Impact News Approaching)");
      return;
     }

   //--- Step 2: Sentimental Analysis - Check for volatility
   if(!HasEnoughVolatility())
     {
      Comment("Signal: WAIT (Market Volatility Too Low)");
      return;
     }

   //--- Step 3: Technical Analysis - Check for trend and entry
   string signal = GetTechnicalSignal();
   Comment("Signal: " + signal);
  }

//+------------------------------------------------------------------+
//| Get the final technical signal after checking all conditions     |
//+------------------------------------------------------------------+
string GetTechnicalSignal()
  {
   //--- Condition 1: Check the main trend
   double trend_ma_value[1];
   double close_price[1];
   if(CopyBuffer(trend_ma_handle, 0, 1, 1, trend_ma_value) <= 0 || CopyClose(_Symbol, _Period, 1, 1, close_price) <= 0)
      return "WAIT (Data Error)";

   bool is_uptrend = (close_price[0] > trend_ma_value[0]);
   bool is_downtrend = (close_price[0] < trend_ma_value[0]);

   //--- Condition 2: Check for MACD Crossover
   double macd_main[3], macd_signal[3];
   if(CopyBuffer(macd_handle, 0, 0, 3, macd_main) <= 0 || CopyBuffer(macd_handle, 1, 0, 3, macd_signal) <= 0)
      return "WAIT (Data Error)";
      
   ArraySetAsSeries(macd_main, true);
   ArraySetAsSeries(macd_signal, true);

   bool bullish_cross = macd_main[2] < macd_signal[2] && macd_main[1] > macd_signal[1];
   bool bearish_cross = macd_main[2] > macd_signal[2] && macd_main[1] < macd_signal[1];

   //--- Condition 3: Check RSI level
   double rsi_value[2];
   if(CopyBuffer(rsi_handle, 0, 1, 2, rsi_value) <= 0)
      return "WAIT (Data Error)";
      
   bool rsi_ok_for_buy = rsi_value[0] < rsi_overbought;
   bool rsi_ok_for_sell = rsi_value[0] > rsi_oversold;

   //--- Combine all technical conditions
   if(is_uptrend && bullish_cross && rsi_ok_for_buy)
     {
      return "BUY";
     }

   if(is_downtrend && bearish_cross && rsi_ok_for_sell)
     {
      return "SELL";
     }

   return "WAIT";
  }

//+------------------------------------------------------------------+
//| Check if market has enough volatility using ATR                  |
//+------------------------------------------------------------------+
bool HasEnoughVolatility()
  {
   double atr_buffer[1];
   if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) <= 0)
      return false; // Fail safe

   return(atr_buffer[0] > atr_min_threshold);
  }

//+------------------------------------------------------------------+
//| Fetch and parse news data from Forex Factory's calendar          |
//+------------------------------------------------------------------+
void FetchNewsData()
  {
   char data[];
   string headers;
   string url = "https://nfs.forexfactory.net/ff_calendar_thisweek.xml";
   int res = WebRequest("GET", url, "", NULL, 5000, data, 0, headers);

   if(res == -1)
     {
      Print("WebRequest failed. Error code: ", GetLastError());
      return;
     }

   string xml_data = CharArrayToString(data);
   ArrayResize(upcoming_events, 0);

   int current_pos = 0;
   string event_tag = "<event>";
   while((current_pos = StringFind(xml_data, event_tag, current_pos)) != -1)
     {
      string event_block = StringSubstr(xml_data, current_pos);
      
      string title = GetXmlTagValue(event_block, "title");
      string country = GetXmlTagValue(event_block, "country");
      string date = GetXmlTagValue(event_block, "date");
      string time = GetXmlTagValue(event_block, "time");
      string impact = GetXmlTagValue(event_block, "impact");
      
      //--- We only care about high impact news for EUR and USD
      if((country == "EUR" || country == "USD") && impact == "High")
        {
         datetime event_time = StringToTime(date + " " + time);
         
         int size = ArraySize(upcoming_events);
         ArrayResize(upcoming_events, size + 1);
         upcoming_events[size].time = event_time;
         upcoming_events[size].currency = country;
         upcoming_events[size].impact = impact;
        }

      current_pos += StringLen(event_tag);
     }
   Print("Fetched and parsed ", ArraySize(upcoming_events), " high-impact news events.");
  }

//+------------------------------------------------------------------+
//| Helper function to extract value from an XML-like tag            |
//+------------------------------------------------------------------+
string GetXmlTagValue(string &block, string tag)
  {
   string start_tag = "<" + tag + ">";
   string end_tag = "</" + tag + ">";
   int start_pos = StringFind(block, start_tag);
   if(start_pos == -1) return "";
   
   start_pos += StringLen(start_tag);
   int end_pos = StringFind(block, end_tag, start_pos);
   if(end_pos == -1) return "";

   return StringSubstr(block, start_pos, end_pos - start_pos);
  }

//+------------------------------------------------------------------+
//| Check if a high-impact news event is near the current time       |
//+------------------------------------------------------------------+
bool IsNearHighImpactNews()
  {
   datetime current_time = TimeCurrent();
   for(int i = 0; i < ArraySize(upcoming_events); i++)
     {
      long time_diff = (long)upcoming_events[i].time - (long)current_time;

      // Check if news is coming up
      if(time_diff > 0 && time_diff < minutes_before_news * 60)
        {
         return true;
        }
        
      // Check if news just passed
      if(time_diff < 0 && MathAbs(time_diff) < minutes_after_news * 60)
        {
         return true;
        }
     }
   return false;
  }
//+------------------------------------------------------------------+
