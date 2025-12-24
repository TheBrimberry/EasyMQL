//+------------------------------------------------------------------+
//|                                         TradingAssistantEA.mq5   |
//|                        Trading Assistant with LLM Integration    |
//|                         Powered by FinBot AI Predictions         |
//+------------------------------------------------------------------+
#property copyright "EasyMQL Trading Assistant"
#property link      "https://github.com/TheBrimberry/EasyMQL"
#property version   "1.00"
#property description "AI-Powered Trading Assistant using LLM predictions"
#property description "Integrates with FinBot API for market analysis"

//--- Include EasyMQL framework
#include "../Expert/Expert.mqh"
#include "../Expert/Signal/SignalMA.mqh"
#include "../Expert/Money/MoneyFixedRisk.mqh"
#include "../Expert/Trailing/TrailingFixedPips.mqh"
#include "../trade/Trade.mqh"
#include "../common/JSON.mqh"

//--- Include Trading Assistant modules
#include "LLMConnector.mqh"
#include "PredictionSignal.mqh"
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== API Configuration ==="
input string   InpAPIUrl           = "http://localhost:8000";  // Prediction API URL
input string   InpAPIKey           = "";                        // API Key (optional)
input int      InpAPITimeout       = 5000;                      // API Timeout (ms)
input bool     InpUseLocalFallback = true;                      // Use local signals if API fails

input group "=== Trading Settings ==="
input double   InpRiskPercent      = 1.0;                       // Risk per trade (%)
input double   InpMaxDrawdown      = 10.0;                      // Max drawdown (%)
input int      InpMaxPositions     = 3;                         // Max simultaneous positions
input int      InpMagicNumber      = 202501;                    // Magic number

input group "=== Signal Settings ==="
input double   InpMinConfidence    = 0.7;                       // Min prediction confidence
input bool     InpUseTechnicalConf = true;                      // Confirm with technical analysis
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1;                 // Trading timeframe

input group "=== LLM Analysis Settings ==="
input bool     InpUseSentiment     = true;                      // Use sentiment analysis
input bool     InpUseNewsAnalysis  = true;                      // Use news analysis
input bool     InpUsePricePattern  = true;                      // Use price pattern recognition
input int      InpLookbackPeriods  = 100;                       // Historical periods for analysis

input group "=== Risk Management ==="
input double   InpStopLoss         = 50.0;                      // Stop Loss (pips)
input double   InpTakeProfit       = 100.0;                     // Take Profit (pips)
input bool     InpUseTrailingStop  = true;                      // Use trailing stop
input double   InpTrailingStop     = 30.0;                      // Trailing stop (pips)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CLLMConnector    g_LLMConnector;
CPredictionSignal g_PredictionSignal;
CRiskManager     g_RiskManager;
CTrade           g_Trade;

datetime         g_LastBarTime = 0;
datetime         g_LastAPICall = 0;
int              g_APICallInterval = 60;  // Seconds between API calls

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize trade object
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(10);
   g_Trade.SetTypeFilling(ORDER_FILLING_IOC);

   //--- Initialize LLM Connector
   if(!g_LLMConnector.Initialize(InpAPIUrl, InpAPIKey, InpAPITimeout))
   {
      Print("Warning: Failed to initialize LLM Connector. Using local signals only.");
      if(!InpUseLocalFallback)
      {
         Print("Error: Local fallback disabled. EA cannot operate.");
         return INIT_FAILED;
      }
   }

   //--- Initialize Prediction Signal
   g_PredictionSignal.Initialize(InpMinConfidence, InpUseTechnicalConf);
   g_PredictionSignal.SetAnalysisOptions(InpUseSentiment, InpUseNewsAnalysis, InpUsePricePattern);
   g_PredictionSignal.SetLookback(InpLookbackPeriods);

   //--- Initialize Risk Manager
   g_RiskManager.Initialize(InpRiskPercent, InpMaxDrawdown, InpMaxPositions);
   g_RiskManager.SetStopLoss(InpStopLoss);
   g_RiskManager.SetTakeProfit(InpTakeProfit);

   //--- Display initialization info
   Print("=================================================");
   Print("Trading Assistant EA v1.00 initialized");
   Print("API URL: ", InpAPIUrl);
   Print("Risk per trade: ", InpRiskPercent, "%");
   Print("Max positions: ", InpMaxPositions);
   Print("Min confidence: ", InpMinConfidence);
   Print("=================================================");

   //--- Create dashboard comment
   UpdateDashboard();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_LLMConnector.Shutdown();
   Comment("");
   Print("Trading Assistant EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   datetime currentBarTime = iTime(_Symbol, InpTimeframe, 0);
   if(currentBarTime == g_LastBarTime)
      return;
   g_LastBarTime = currentBarTime;

   //--- Check if trading is allowed
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("Trading not allowed by terminal");
      return;
   }

   //--- Update risk manager
   g_RiskManager.Update();

   //--- Check drawdown limit
   if(g_RiskManager.IsDrawdownExceeded())
   {
      Print("Drawdown limit exceeded. No new trades allowed.");
      UpdateDashboard();
      return;
   }

   //--- Check max positions
   if(g_RiskManager.GetOpenPositions() >= InpMaxPositions)
   {
      UpdateDashboard();
      return;
   }

   //--- Get prediction from LLM
   SPrediction prediction;
   bool apiSuccess = false;

   //--- Rate limit API calls
   if(TimeCurrent() - g_LastAPICall >= g_APICallInterval)
   {
      apiSuccess = g_LLMConnector.GetPrediction(_Symbol, InpTimeframe, prediction);
      g_LastAPICall = TimeCurrent();
   }

   //--- Fallback to local analysis if API fails
   if(!apiSuccess && InpUseLocalFallback)
   {
      prediction = g_PredictionSignal.GenerateLocalPrediction(_Symbol, InpTimeframe);
   }

   //--- Validate prediction
   if(prediction.confidence < InpMinConfidence)
   {
      UpdateDashboard(prediction);
      return;
   }

   //--- Confirm with technical analysis if enabled
   if(InpUseTechnicalConf)
   {
      if(!g_PredictionSignal.ConfirmWithTechnicals(_Symbol, InpTimeframe, prediction.direction))
      {
         Print("Technical confirmation failed for ", prediction.direction == 1 ? "BUY" : "SELL");
         UpdateDashboard(prediction);
         return;
      }
   }

   //--- Execute trade
   ExecuteTrade(prediction);

   //--- Manage existing positions
   ManagePositions();

   //--- Update dashboard
   UpdateDashboard(prediction);
}

//+------------------------------------------------------------------+
//| Execute trade based on prediction                                 |
//+------------------------------------------------------------------+
void ExecuteTrade(const SPrediction &prediction)
{
   //--- Calculate lot size based on risk
   double lotSize = g_RiskManager.CalculateLotSize(_Symbol, InpStopLoss);

   if(lotSize <= 0)
   {
      Print("Invalid lot size calculated");
      return;
   }

   //--- Get current prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   //--- Calculate SL/TP
   double sl, tp;

   if(prediction.direction == 1)  // BUY
   {
      sl = NormalizeDouble(ask - InpStopLoss * point * 10, digits);
      tp = NormalizeDouble(ask + InpTakeProfit * point * 10, digits);

      if(g_Trade.Buy(lotSize, _Symbol, ask, sl, tp,
         StringFormat("AI Pred: %.2f%% conf", prediction.confidence * 100)))
      {
         Print("BUY order placed. Confidence: ", prediction.confidence * 100, "%");
         Print("Reason: ", prediction.reason);
      }
      else
      {
         Print("BUY order failed. Error: ", GetLastError());
      }
   }
   else if(prediction.direction == -1)  // SELL
   {
      sl = NormalizeDouble(bid + InpStopLoss * point * 10, digits);
      tp = NormalizeDouble(bid - InpTakeProfit * point * 10, digits);

      if(g_Trade.Sell(lotSize, _Symbol, bid, sl, tp,
         StringFormat("AI Pred: %.2f%% conf", prediction.confidence * 100)))
      {
         Print("SELL order placed. Confidence: ", prediction.confidence * 100, "%");
         Print("Reason: ", prediction.reason);
      }
      else
      {
         Print("SELL order failed. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions (trailing stop, etc.)                   |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!InpUseTrailingStop)
      return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      double positionType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      double trailDistance = InpTrailingStop * point * 10;

      if(positionType == POSITION_TYPE_BUY)
      {
         double newSL = NormalizeDouble(bid - trailDistance, digits);
         if(newSL > currentSL && newSL < bid)
         {
            g_Trade.PositionModify(ticket, newSL, currentTP);
         }
      }
      else if(positionType == POSITION_TYPE_SELL)
      {
         double newSL = NormalizeDouble(ask + trailDistance, digits);
         if((newSL < currentSL || currentSL == 0) && newSL > ask)
         {
            g_Trade.PositionModify(ticket, newSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update chart dashboard                                            |
//+------------------------------------------------------------------+
void UpdateDashboard(const SPrediction &prediction = SPrediction())
{
   string dashboard = "";
   dashboard += "╔══════════════════════════════════════════╗\n";
   dashboard += "║     TRADING ASSISTANT EA v1.00           ║\n";
   dashboard += "║        AI-Powered Trading System         ║\n";
   dashboard += "╠══════════════════════════════════════════╣\n";
   dashboard += StringFormat("║ Symbol: %-15s TF: %-10s  ║\n", _Symbol, EnumToString(InpTimeframe));
   dashboard += "╠══════════════════════════════════════════╣\n";
   dashboard += StringFormat("║ Open Positions: %d / %d                    ║\n",
                             g_RiskManager.GetOpenPositions(), InpMaxPositions);
   dashboard += StringFormat("║ Current Drawdown: %.2f%%                   ║\n",
                             g_RiskManager.GetCurrentDrawdown());
   dashboard += "╠══════════════════════════════════════════╣\n";

   if(prediction.confidence > 0)
   {
      string direction = prediction.direction == 1 ? "BUY " : (prediction.direction == -1 ? "SELL" : "HOLD");
      dashboard += StringFormat("║ Last Signal: %s                          ║\n", direction);
      dashboard += StringFormat("║ Confidence: %.1f%%                         ║\n", prediction.confidence * 100);
      dashboard += StringFormat("║ Sentiment: %.2f                          ║\n", prediction.sentiment);
   }
   else
   {
      dashboard += "║ Waiting for signal...                    ║\n";
   }

   dashboard += "╠══════════════════════════════════════════╣\n";
   dashboard += StringFormat("║ API Status: %s                     ║\n",
                             g_LLMConnector.IsConnected() ? "Connected   " : "Disconnected");
   dashboard += "╚══════════════════════════════════════════╝\n";

   Comment(dashboard);
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         Print("Trade executed: ", trans.deal_type == DEAL_TYPE_BUY ? "BUY" : "SELL",
               " Volume: ", trans.volume,
               " Price: ", trans.price);
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function for periodic updates                               |
//+------------------------------------------------------------------+
void OnTimer()
{
   //--- Periodic health check
   if(!g_LLMConnector.IsConnected())
   {
      g_LLMConnector.Reconnect();
   }
}

//+------------------------------------------------------------------+
