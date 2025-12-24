//+------------------------------------------------------------------+
//|                                            PredictionSignal.mqh   |
//|                         Local Signal Generation with ML Patterns  |
//|                         Fallback when LLM API is unavailable      |
//+------------------------------------------------------------------+
#property copyright "EasyMQL Trading Assistant"
#property link      "https://github.com/TheBrimberry/EasyMQL"

#include "LLMConnector.mqh"
#include "../Indicators/Oscilators.mqh"
#include "../Indicators/Trend.mqh"

//+------------------------------------------------------------------+
//| Prediction Signal Class                                           |
//+------------------------------------------------------------------+
class CPredictionSignal
{
private:
   double            m_MinConfidence;
   bool              m_UseTechnicalConf;
   bool              m_UseSentiment;
   bool              m_UseNewsAnalysis;
   bool              m_UsePricePattern;
   int               m_LookbackPeriods;

   //--- Indicator handles
   int               m_HandleRSI;
   int               m_HandleMACD;
   int               m_HandleMA20;
   int               m_HandleMA50;
   int               m_HandleATR;
   int               m_HandleBB;

   //--- Analysis methods
   double            AnalyzeTrend(const string symbol, const ENUM_TIMEFRAMES timeframe);
   double            AnalyzeMomentum(const string symbol, const ENUM_TIMEFRAMES timeframe);
   double            AnalyzeVolatility(const string symbol, const ENUM_TIMEFRAMES timeframe);
   double            DetectPatterns(const string symbol, const ENUM_TIMEFRAMES timeframe);
   double            CalculateSignalStrength(double trend, double momentum, double patterns);

   //--- Pattern detection
   bool              IsBullishEngulfing(const string symbol, const ENUM_TIMEFRAMES timeframe);
   bool              IsBearishEngulfing(const string symbol, const ENUM_TIMEFRAMES timeframe);
   bool              IsDojiPattern(const string symbol, const ENUM_TIMEFRAMES timeframe);
   bool              IsHammerPattern(const string symbol, const ENUM_TIMEFRAMES timeframe);
   bool              IsShootingStarPattern(const string symbol, const ENUM_TIMEFRAMES timeframe);

public:
                     CPredictionSignal();
                    ~CPredictionSignal();

   //--- Initialization
   bool              Initialize(double minConfidence, bool useTechnicalConf);
   void              SetAnalysisOptions(bool sentiment, bool news, bool patterns);
   void              SetLookback(int periods) { m_LookbackPeriods = periods; }

   //--- Signal generation
   SPrediction       GenerateLocalPrediction(const string symbol, const ENUM_TIMEFRAMES timeframe);
   bool              ConfirmWithTechnicals(const string symbol, const ENUM_TIMEFRAMES timeframe, int direction);

   //--- Indicator access
   double            GetRSI(const string symbol, const ENUM_TIMEFRAMES timeframe);
   double            GetMACD(const string symbol, const ENUM_TIMEFRAMES timeframe);
   double            GetTrendStrength(const string symbol, const ENUM_TIMEFRAMES timeframe);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CPredictionSignal::CPredictionSignal()
{
   m_MinConfidence = 0.7;
   m_UseTechnicalConf = true;
   m_UseSentiment = true;
   m_UseNewsAnalysis = true;
   m_UsePricePattern = true;
   m_LookbackPeriods = 100;

   m_HandleRSI = INVALID_HANDLE;
   m_HandleMACD = INVALID_HANDLE;
   m_HandleMA20 = INVALID_HANDLE;
   m_HandleMA50 = INVALID_HANDLE;
   m_HandleATR = INVALID_HANDLE;
   m_HandleBB = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CPredictionSignal::~CPredictionSignal()
{
   if(m_HandleRSI != INVALID_HANDLE) IndicatorRelease(m_HandleRSI);
   if(m_HandleMACD != INVALID_HANDLE) IndicatorRelease(m_HandleMACD);
   if(m_HandleMA20 != INVALID_HANDLE) IndicatorRelease(m_HandleMA20);
   if(m_HandleMA50 != INVALID_HANDLE) IndicatorRelease(m_HandleMA50);
   if(m_HandleATR != INVALID_HANDLE) IndicatorRelease(m_HandleATR);
   if(m_HandleBB != INVALID_HANDLE) IndicatorRelease(m_HandleBB);
}

//+------------------------------------------------------------------+
//| Initialize signal generator                                       |
//+------------------------------------------------------------------+
bool CPredictionSignal::Initialize(double minConfidence, bool useTechnicalConf)
{
   m_MinConfidence = minConfidence;
   m_UseTechnicalConf = useTechnicalConf;

   return true;
}

//+------------------------------------------------------------------+
//| Set analysis options                                              |
//+------------------------------------------------------------------+
void CPredictionSignal::SetAnalysisOptions(bool sentiment, bool news, bool patterns)
{
   m_UseSentiment = sentiment;
   m_UseNewsAnalysis = news;
   m_UsePricePattern = patterns;
}

//+------------------------------------------------------------------+
//| Generate local prediction using technical analysis                |
//+------------------------------------------------------------------+
SPrediction CPredictionSignal::GenerateLocalPrediction(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   SPrediction prediction;
   prediction.Reset();

   //--- Analyze trend
   double trendScore = AnalyzeTrend(symbol, timeframe);

   //--- Analyze momentum
   double momentumScore = AnalyzeMomentum(symbol, timeframe);

   //--- Detect patterns
   double patternScore = 0;
   if(m_UsePricePattern)
   {
      patternScore = DetectPatterns(symbol, timeframe);
   }

   //--- Calculate overall signal
   double signalStrength = CalculateSignalStrength(trendScore, momentumScore, patternScore);

   //--- Determine direction
   if(signalStrength > 0.3)
   {
      prediction.direction = 1;  // BUY
      prediction.confidence = MathMin(signalStrength, 1.0);
   }
   else if(signalStrength < -0.3)
   {
      prediction.direction = -1;  // SELL
      prediction.confidence = MathMin(MathAbs(signalStrength), 1.0);
   }
   else
   {
      prediction.direction = 0;  // HOLD
      prediction.confidence = 0.5;
   }

   //--- Calculate sentiment based on technicals
   prediction.sentiment = trendScore;

   //--- Generate reason
   string trendDir = trendScore > 0 ? "bullish" : "bearish";
   string momDir = momentumScore > 0 ? "positive" : "negative";

   prediction.reason = StringFormat("Local analysis: %s trend (%.2f), %s momentum (%.2f)",
                                     trendDir, trendScore, momDir, momentumScore);

   if(patternScore != 0)
   {
      prediction.reason += StringFormat(", pattern signal (%.2f)", patternScore);
   }

   //--- Set validity
   prediction.validUntil = TimeCurrent() + PeriodSeconds(timeframe);

   Print("Local prediction generated: ", prediction.direction == 1 ? "BUY" : (prediction.direction == -1 ? "SELL" : "HOLD"),
         " Confidence: ", DoubleToString(prediction.confidence * 100, 1), "%");

   return prediction;
}

//+------------------------------------------------------------------+
//| Analyze trend                                                     |
//+------------------------------------------------------------------+
double CPredictionSignal::AnalyzeTrend(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double score = 0;

   //--- Get MA values
   double ma20[], ma50[];
   ArraySetAsSeries(ma20, true);
   ArraySetAsSeries(ma50, true);

   int handleMA20 = iMA(symbol, timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   int handleMA50 = iMA(symbol, timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(handleMA20 == INVALID_HANDLE || handleMA50 == INVALID_HANDLE)
      return 0;

   CopyBuffer(handleMA20, 0, 0, 3, ma20);
   CopyBuffer(handleMA50, 0, 0, 3, ma50);

   //--- Get current price
   double close[];
   ArraySetAsSeries(close, true);
   CopyClose(symbol, timeframe, 0, 3, close);

   //--- Trend analysis
   //--- Price above MA20 and MA50 = bullish
   if(close[0] > ma20[0] && close[0] > ma50[0])
   {
      score += 0.3;
   }
   else if(close[0] < ma20[0] && close[0] < ma50[0])
   {
      score -= 0.3;
   }

   //--- MA20 above MA50 = bullish
   if(ma20[0] > ma50[0])
   {
      score += 0.2;
      //--- Golden cross
      if(ma20[1] <= ma50[1])
         score += 0.3;
   }
   else
   {
      score -= 0.2;
      //--- Death cross
      if(ma20[1] >= ma50[1])
         score -= 0.3;
   }

   //--- MA slope
   double ma20Slope = (ma20[0] - ma20[2]) / ma20[2] * 100;
   if(ma20Slope > 0.1)
      score += 0.2;
   else if(ma20Slope < -0.1)
      score -= 0.2;

   IndicatorRelease(handleMA20);
   IndicatorRelease(handleMA50);

   return MathMax(-1, MathMin(1, score));
}

//+------------------------------------------------------------------+
//| Analyze momentum                                                  |
//+------------------------------------------------------------------+
double CPredictionSignal::AnalyzeMomentum(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double score = 0;

   //--- RSI Analysis
   double rsi[];
   ArraySetAsSeries(rsi, true);

   int handleRSI = iRSI(symbol, timeframe, 14, PRICE_CLOSE);
   if(handleRSI != INVALID_HANDLE)
   {
      CopyBuffer(handleRSI, 0, 0, 3, rsi);

      if(rsi[0] < 30)
      {
         score += 0.4;  // Oversold - bullish
         if(rsi[0] < 20) score += 0.2;
      }
      else if(rsi[0] > 70)
      {
         score -= 0.4;  // Overbought - bearish
         if(rsi[0] > 80) score -= 0.2;
      }
      else if(rsi[0] > 50)
      {
         score += 0.1;
      }
      else
      {
         score -= 0.1;
      }

      //--- RSI divergence check (simplified)
      if(rsi[0] > rsi[1] && rsi[1] > rsi[2])
         score += 0.1;  // Rising RSI
      else if(rsi[0] < rsi[1] && rsi[1] < rsi[2])
         score -= 0.1;  // Falling RSI

      IndicatorRelease(handleRSI);
   }

   //--- MACD Analysis
   double macdMain[], macdSignal[], macdHist[];
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   ArraySetAsSeries(macdHist, true);

   int handleMACD = iMACD(symbol, timeframe, 12, 26, 9, PRICE_CLOSE);
   if(handleMACD != INVALID_HANDLE)
   {
      CopyBuffer(handleMACD, 0, 0, 3, macdMain);
      CopyBuffer(handleMACD, 1, 0, 3, macdSignal);
      CopyBuffer(handleMACD, 2, 0, 3, macdHist);

      //--- MACD crossover
      if(macdMain[0] > macdSignal[0])
      {
         score += 0.2;
         if(macdMain[1] <= macdSignal[1])
            score += 0.2;  // Bullish crossover
      }
      else
      {
         score -= 0.2;
         if(macdMain[1] >= macdSignal[1])
            score -= 0.2;  // Bearish crossover
      }

      //--- Histogram momentum
      if(macdHist[0] > macdHist[1])
         score += 0.1;
      else
         score -= 0.1;

      IndicatorRelease(handleMACD);
   }

   return MathMax(-1, MathMin(1, score));
}

//+------------------------------------------------------------------+
//| Analyze volatility                                                |
//+------------------------------------------------------------------+
double CPredictionSignal::AnalyzeVolatility(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double atr[];
   ArraySetAsSeries(atr, true);

   int handleATR = iATR(symbol, timeframe, 14);
   if(handleATR == INVALID_HANDLE)
      return 0;

   CopyBuffer(handleATR, 0, 0, 20, atr);

   //--- Calculate average ATR
   double avgATR = 0;
   for(int i = 0; i < 20; i++)
      avgATR += atr[i];
   avgATR /= 20;

   //--- Current volatility vs average
   double volatilityRatio = atr[0] / avgATR;

   IndicatorRelease(handleATR);

   return volatilityRatio;
}

//+------------------------------------------------------------------+
//| Detect candlestick patterns                                       |
//+------------------------------------------------------------------+
double CPredictionSignal::DetectPatterns(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double score = 0;

   if(IsBullishEngulfing(symbol, timeframe))
      score += 0.5;

   if(IsBearishEngulfing(symbol, timeframe))
      score -= 0.5;

   if(IsHammerPattern(symbol, timeframe))
      score += 0.3;

   if(IsShootingStarPattern(symbol, timeframe))
      score -= 0.3;

   if(IsDojiPattern(symbol, timeframe))
   {
      //--- Doji at extremes can signal reversal
      double rsi[];
      ArraySetAsSeries(rsi, true);
      int handleRSI = iRSI(symbol, timeframe, 14, PRICE_CLOSE);
      if(handleRSI != INVALID_HANDLE)
      {
         CopyBuffer(handleRSI, 0, 0, 1, rsi);
         if(rsi[0] < 30)
            score += 0.2;
         else if(rsi[0] > 70)
            score -= 0.2;
         IndicatorRelease(handleRSI);
      }
   }

   return MathMax(-1, MathMin(1, score));
}

//+------------------------------------------------------------------+
//| Calculate overall signal strength                                 |
//+------------------------------------------------------------------+
double CPredictionSignal::CalculateSignalStrength(double trend, double momentum, double patterns)
{
   //--- Weight the signals
   double trendWeight = 0.4;
   double momentumWeight = 0.4;
   double patternWeight = 0.2;

   double totalWeight = trendWeight + momentumWeight;
   if(m_UsePricePattern)
      totalWeight += patternWeight;

   double signal = (trend * trendWeight + momentum * momentumWeight);
   if(m_UsePricePattern)
      signal += patterns * patternWeight;

   signal /= totalWeight;

   //--- Boost signal if all indicators agree
   if((trend > 0 && momentum > 0 && patterns >= 0) ||
      (trend < 0 && momentum < 0 && patterns <= 0))
   {
      signal *= 1.2;
   }

   return MathMax(-1, MathMin(1, signal));
}

//+------------------------------------------------------------------+
//| Confirm prediction with technical indicators                      |
//+------------------------------------------------------------------+
bool CPredictionSignal::ConfirmWithTechnicals(const string symbol, const ENUM_TIMEFRAMES timeframe, int direction)
{
   double trend = AnalyzeTrend(symbol, timeframe);
   double momentum = AnalyzeMomentum(symbol, timeframe);

   //--- For BUY, we need positive trend or momentum
   if(direction == 1)
   {
      return (trend > 0 || momentum > 0.2);
   }
   //--- For SELL, we need negative trend or momentum
   else if(direction == -1)
   {
      return (trend < 0 || momentum < -0.2);
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check for bullish engulfing pattern                               |
//+------------------------------------------------------------------+
bool CPredictionSignal::IsBullishEngulfing(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double open[], close[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   CopyOpen(symbol, timeframe, 0, 3, open);
   CopyClose(symbol, timeframe, 0, 3, close);
   CopyHigh(symbol, timeframe, 0, 3, high);
   CopyLow(symbol, timeframe, 0, 3, low);

   //--- Previous candle is bearish
   bool prevBearish = close[1] < open[1];

   //--- Current candle is bullish
   bool currBullish = close[0] > open[0];

   //--- Current body engulfs previous
   bool engulfs = open[0] <= close[1] && close[0] >= open[1];

   return prevBearish && currBullish && engulfs;
}

//+------------------------------------------------------------------+
//| Check for bearish engulfing pattern                               |
//+------------------------------------------------------------------+
bool CPredictionSignal::IsBearishEngulfing(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double open[], close[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   CopyOpen(symbol, timeframe, 0, 3, open);
   CopyClose(symbol, timeframe, 0, 3, close);
   CopyHigh(symbol, timeframe, 0, 3, high);
   CopyLow(symbol, timeframe, 0, 3, low);

   //--- Previous candle is bullish
   bool prevBullish = close[1] > open[1];

   //--- Current candle is bearish
   bool currBearish = close[0] < open[0];

   //--- Current body engulfs previous
   bool engulfs = open[0] >= close[1] && close[0] <= open[1];

   return prevBullish && currBearish && engulfs;
}

//+------------------------------------------------------------------+
//| Check for doji pattern                                            |
//+------------------------------------------------------------------+
bool CPredictionSignal::IsDojiPattern(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double open[], close[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   CopyOpen(symbol, timeframe, 0, 2, open);
   CopyClose(symbol, timeframe, 0, 2, close);
   CopyHigh(symbol, timeframe, 0, 2, high);
   CopyLow(symbol, timeframe, 0, 2, low);

   double body = MathAbs(close[0] - open[0]);
   double range = high[0] - low[0];

   //--- Doji has very small body relative to range
   return range > 0 && body / range < 0.1;
}

//+------------------------------------------------------------------+
//| Check for hammer pattern                                          |
//+------------------------------------------------------------------+
bool CPredictionSignal::IsHammerPattern(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double open[], close[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   CopyOpen(symbol, timeframe, 0, 2, open);
   CopyClose(symbol, timeframe, 0, 2, close);
   CopyHigh(symbol, timeframe, 0, 2, high);
   CopyLow(symbol, timeframe, 0, 2, low);

   double body = MathAbs(close[0] - open[0]);
   double range = high[0] - low[0];
   double upperWick = high[0] - MathMax(open[0], close[0]);
   double lowerWick = MathMin(open[0], close[0]) - low[0];

   //--- Hammer: small body at top, long lower wick
   return range > 0 &&
          body / range < 0.3 &&
          lowerWick > body * 2 &&
          upperWick < body;
}

//+------------------------------------------------------------------+
//| Check for shooting star pattern                                   |
//+------------------------------------------------------------------+
bool CPredictionSignal::IsShootingStarPattern(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double open[], close[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   CopyOpen(symbol, timeframe, 0, 2, open);
   CopyClose(symbol, timeframe, 0, 2, close);
   CopyHigh(symbol, timeframe, 0, 2, high);
   CopyLow(symbol, timeframe, 0, 2, low);

   double body = MathAbs(close[0] - open[0]);
   double range = high[0] - low[0];
   double upperWick = high[0] - MathMax(open[0], close[0]);
   double lowerWick = MathMin(open[0], close[0]) - low[0];

   //--- Shooting star: small body at bottom, long upper wick
   return range > 0 &&
          body / range < 0.3 &&
          upperWick > body * 2 &&
          lowerWick < body;
}

//+------------------------------------------------------------------+
//| Get RSI value                                                     |
//+------------------------------------------------------------------+
double CPredictionSignal::GetRSI(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double rsi[];
   ArraySetAsSeries(rsi, true);

   int handle = iRSI(symbol, timeframe, 14, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return 50;

   CopyBuffer(handle, 0, 0, 1, rsi);
   IndicatorRelease(handle);

   return rsi[0];
}

//+------------------------------------------------------------------+
//| Get MACD value                                                    |
//+------------------------------------------------------------------+
double CPredictionSignal::GetMACD(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   double macd[];
   ArraySetAsSeries(macd, true);

   int handle = iMACD(symbol, timeframe, 12, 26, 9, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return 0;

   CopyBuffer(handle, 0, 0, 1, macd);
   IndicatorRelease(handle);

   return macd[0];
}

//+------------------------------------------------------------------+
//| Get trend strength                                                |
//+------------------------------------------------------------------+
double CPredictionSignal::GetTrendStrength(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   return AnalyzeTrend(symbol, timeframe);
}

//+------------------------------------------------------------------+
