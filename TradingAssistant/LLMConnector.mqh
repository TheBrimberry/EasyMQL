//+------------------------------------------------------------------+
//|                                                LLMConnector.mqh   |
//|                         LLM API Connector for Trading Assistant   |
//|                         Connects to FinBot Prediction Service     |
//+------------------------------------------------------------------+
#property copyright "EasyMQL Trading Assistant"
#property link      "https://github.com/TheBrimberry/EasyMQL"

#include "../common/JSON.mqh"

//+------------------------------------------------------------------+
//| Prediction structure                                              |
//+------------------------------------------------------------------+
struct SPrediction
{
   int      direction;      // 1 = BUY, -1 = SELL, 0 = HOLD
   double   confidence;     // 0.0 to 1.0
   double   sentiment;      // -1.0 to 1.0
   double   priceTarget;    // Predicted price target
   double   stopLoss;       // Suggested stop loss
   double   takeProfit;     // Suggested take profit
   string   reason;         // LLM explanation
   string   newsImpact;     // News summary
   datetime validUntil;     // Prediction validity

   void Reset()
   {
      direction = 0;
      confidence = 0;
      sentiment = 0;
      priceTarget = 0;
      stopLoss = 0;
      takeProfit = 0;
      reason = "";
      newsImpact = "";
      validUntil = 0;
   }
};

//+------------------------------------------------------------------+
//| Market data structure for API request                             |
//+------------------------------------------------------------------+
struct SMarketData
{
   string   symbol;
   double   open[];
   double   high[];
   double   low[];
   double   close[];
   long     volume[];
   datetime time[];
};

//+------------------------------------------------------------------+
//| LLM Connector Class                                               |
//+------------------------------------------------------------------+
class CLLMConnector
{
private:
   string            m_APIUrl;
   string            m_APIKey;
   int               m_Timeout;
   bool              m_Connected;
   datetime          m_LastConnectionCheck;
   int               m_RetryCount;
   int               m_MaxRetries;

   //--- Internal methods
   string            BuildRequestBody(const string symbol, const ENUM_TIMEFRAMES timeframe);
   bool              ParseResponse(const string response, SPrediction &prediction);
   string            GetMarketDataJSON(const string symbol, const ENUM_TIMEFRAMES timeframe);

public:
                     CLLMConnector();
                    ~CLLMConnector();

   //--- Initialization
   bool              Initialize(const string url, const string apiKey, const int timeout);
   void              Shutdown();

   //--- Connection management
   bool              IsConnected() { return m_Connected; }
   bool              Reconnect();
   bool              TestConnection();

   //--- Prediction methods
   bool              GetPrediction(const string symbol, const ENUM_TIMEFRAMES timeframe, SPrediction &prediction);
   bool              GetBatchPredictions(string &symbols[], const ENUM_TIMEFRAMES timeframe, SPrediction &predictions[]);

   //--- News and sentiment
   bool              GetNewsSentiment(const string symbol, double &sentiment, string &summary);
   bool              GetMarketAnalysis(const string symbol, string &analysis);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CLLMConnector::CLLMConnector()
{
   m_APIUrl = "";
   m_APIKey = "";
   m_Timeout = 5000;
   m_Connected = false;
   m_LastConnectionCheck = 0;
   m_RetryCount = 0;
   m_MaxRetries = 3;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CLLMConnector::~CLLMConnector()
{
   Shutdown();
}

//+------------------------------------------------------------------+
//| Initialize connector                                              |
//+------------------------------------------------------------------+
bool CLLMConnector::Initialize(const string url, const string apiKey, const int timeout)
{
   m_APIUrl = url;
   m_APIKey = apiKey;
   m_Timeout = timeout;

   //--- Test connection
   m_Connected = TestConnection();

   if(m_Connected)
   {
      Print("LLM Connector initialized successfully");
      Print("API Endpoint: ", m_APIUrl);
   }
   else
   {
      Print("LLM Connector initialization failed - API not reachable");
   }

   return m_Connected;
}

//+------------------------------------------------------------------+
//| Shutdown connector                                                |
//+------------------------------------------------------------------+
void CLLMConnector::Shutdown()
{
   m_Connected = false;
   Print("LLM Connector shutdown");
}

//+------------------------------------------------------------------+
//| Test API connection                                               |
//+------------------------------------------------------------------+
bool CLLMConnector::TestConnection()
{
   string url = m_APIUrl + "/health";
   string headers = "Content-Type: application/json\r\n";
   if(m_APIKey != "")
      headers += "Authorization: Bearer " + m_APIKey + "\r\n";

   char post[];
   char result[];
   string resultHeaders;

   int res = WebRequest(
      "GET",
      url,
      headers,
      m_Timeout,
      post,
      result,
      resultHeaders
   );

   if(res == 200)
   {
      m_Connected = true;
      m_RetryCount = 0;
      return true;
   }

   //--- Handle specific error codes
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4060)
      {
         Print("Error: URL not allowed in WebRequest. Add ", m_APIUrl, " to allowed URLs in MT5 Options.");
      }
      else
      {
         Print("Connection error: ", error);
      }
   }

   m_Connected = false;
   return false;
}

//+------------------------------------------------------------------+
//| Reconnect to API                                                  |
//+------------------------------------------------------------------+
bool CLLMConnector::Reconnect()
{
   if(m_RetryCount >= m_MaxRetries)
   {
      Print("Max reconnection attempts reached");
      return false;
   }

   m_RetryCount++;
   Print("Attempting to reconnect... (", m_RetryCount, "/", m_MaxRetries, ")");

   Sleep(1000 * m_RetryCount);  // Exponential backoff

   return TestConnection();
}

//+------------------------------------------------------------------+
//| Get prediction from LLM API                                       |
//+------------------------------------------------------------------+
bool CLLMConnector::GetPrediction(const string symbol, const ENUM_TIMEFRAMES timeframe, SPrediction &prediction)
{
   prediction.Reset();

   if(!m_Connected && !Reconnect())
   {
      return false;
   }

   //--- Build request
   string url = m_APIUrl + "/api/predict";
   string headers = "Content-Type: application/json\r\n";
   if(m_APIKey != "")
      headers += "Authorization: Bearer " + m_APIKey + "\r\n";

   string body = BuildRequestBody(symbol, timeframe);

   char post[];
   char result[];
   string resultHeaders;

   StringToCharArray(body, post, 0, StringLen(body));

   int res = WebRequest(
      "POST",
      url,
      headers,
      m_Timeout,
      post,
      result,
      resultHeaders
   );

   if(res != 200)
   {
      Print("API request failed with code: ", res);
      m_Connected = false;
      return false;
   }

   //--- Parse response
   string response = CharArrayToString(result);

   return ParseResponse(response, prediction);
}

//+------------------------------------------------------------------+
//| Build request body with market data                               |
//+------------------------------------------------------------------+
string CLLMConnector::BuildRequestBody(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   string json = "{";
   json += "\"symbol\":\"" + symbol + "\",";
   json += "\"timeframe\":\"" + EnumToString(timeframe) + "\",";
   json += "\"timestamp\":" + IntegerToString(TimeCurrent()) + ",";
   json += "\"market_data\":" + GetMarketDataJSON(symbol, timeframe);
   json += "}";

   return json;
}

//+------------------------------------------------------------------+
//| Get market data as JSON                                           |
//+------------------------------------------------------------------+
string CLLMConnector::GetMarketDataJSON(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
   int count = 100;  // Last 100 bars

   double open[], high[], low[], close[];
   long volume[];
   datetime time[];

   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(volume, true);
   ArraySetAsSeries(time, true);

   if(CopyOpen(symbol, timeframe, 0, count, open) <= 0 ||
      CopyHigh(symbol, timeframe, 0, count, high) <= 0 ||
      CopyLow(symbol, timeframe, 0, count, low) <= 0 ||
      CopyClose(symbol, timeframe, 0, count, close) <= 0 ||
      CopyTickVolume(symbol, timeframe, 0, count, volume) <= 0 ||
      CopyTime(symbol, timeframe, 0, count, time) <= 0)
   {
      return "{}";
   }

   string json = "{";

   //--- Open prices
   json += "\"open\":[";
   for(int i = count - 1; i >= 0; i--)
   {
      json += DoubleToString(open[i], 5);
      if(i > 0) json += ",";
   }
   json += "],";

   //--- High prices
   json += "\"high\":[";
   for(int i = count - 1; i >= 0; i--)
   {
      json += DoubleToString(high[i], 5);
      if(i > 0) json += ",";
   }
   json += "],";

   //--- Low prices
   json += "\"low\":[";
   for(int i = count - 1; i >= 0; i--)
   {
      json += DoubleToString(low[i], 5);
      if(i > 0) json += ",";
   }
   json += "],";

   //--- Close prices
   json += "\"close\":[";
   for(int i = count - 1; i >= 0; i--)
   {
      json += DoubleToString(close[i], 5);
      if(i > 0) json += ",";
   }
   json += "],";

   //--- Volume
   json += "\"volume\":[";
   for(int i = count - 1; i >= 0; i--)
   {
      json += IntegerToString(volume[i]);
      if(i > 0) json += ",";
   }
   json += "],";

   //--- Current price info
   json += "\"current_ask\":" + DoubleToString(SymbolInfoDouble(symbol, SYMBOL_ASK), 5) + ",";
   json += "\"current_bid\":" + DoubleToString(SymbolInfoDouble(symbol, SYMBOL_BID), 5) + ",";
   json += "\"spread\":" + IntegerToString(SymbolInfoInteger(symbol, SYMBOL_SPREAD));

   json += "}";

   return json;
}

//+------------------------------------------------------------------+
//| Parse API response                                                |
//+------------------------------------------------------------------+
bool CLLMConnector::ParseResponse(const string response, SPrediction &prediction)
{
   //--- Simple JSON parsing (for production, use proper JSON library)
   //--- Expected format:
   //--- {
   //---   "direction": 1,
   //---   "confidence": 0.85,
   //---   "sentiment": 0.3,
   //---   "price_target": 1.2345,
   //---   "stop_loss": 1.2300,
   //---   "take_profit": 1.2400,
   //---   "reason": "Strong bullish momentum...",
   //---   "news_impact": "Positive economic data..."
   //--- }

   if(StringLen(response) < 10)
   {
      Print("Invalid API response");
      return false;
   }

   //--- Parse direction
   int dirPos = StringFind(response, "\"direction\":");
   if(dirPos >= 0)
   {
      string dirStr = StringSubstr(response, dirPos + 12, 3);
      prediction.direction = (int)StringToInteger(dirStr);
   }

   //--- Parse confidence
   int confPos = StringFind(response, "\"confidence\":");
   if(confPos >= 0)
   {
      string confStr = StringSubstr(response, confPos + 13, 10);
      prediction.confidence = StringToDouble(confStr);
   }

   //--- Parse sentiment
   int sentPos = StringFind(response, "\"sentiment\":");
   if(sentPos >= 0)
   {
      string sentStr = StringSubstr(response, sentPos + 12, 10);
      prediction.sentiment = StringToDouble(sentStr);
   }

   //--- Parse price target
   int ptPos = StringFind(response, "\"price_target\":");
   if(ptPos >= 0)
   {
      string ptStr = StringSubstr(response, ptPos + 15, 15);
      prediction.priceTarget = StringToDouble(ptStr);
   }

   //--- Parse stop loss
   int slPos = StringFind(response, "\"stop_loss\":");
   if(slPos >= 0)
   {
      string slStr = StringSubstr(response, slPos + 12, 15);
      prediction.stopLoss = StringToDouble(slStr);
   }

   //--- Parse take profit
   int tpPos = StringFind(response, "\"take_profit\":");
   if(tpPos >= 0)
   {
      string tpStr = StringSubstr(response, tpPos + 14, 15);
      prediction.takeProfit = StringToDouble(tpStr);
   }

   //--- Parse reason
   int reasonPos = StringFind(response, "\"reason\":\"");
   if(reasonPos >= 0)
   {
      int endPos = StringFind(response, "\"", reasonPos + 10);
      if(endPos > reasonPos)
      {
         prediction.reason = StringSubstr(response, reasonPos + 10, endPos - reasonPos - 10);
      }
   }

   //--- Parse news impact
   int newsPos = StringFind(response, "\"news_impact\":\"");
   if(newsPos >= 0)
   {
      int endPos = StringFind(response, "\"", newsPos + 15);
      if(endPos > newsPos)
      {
         prediction.newsImpact = StringSubstr(response, newsPos + 15, endPos - newsPos - 15);
      }
   }

   //--- Set validity
   prediction.validUntil = TimeCurrent() + 3600;  // Valid for 1 hour

   return prediction.confidence > 0;
}

//+------------------------------------------------------------------+
//| Get batch predictions                                             |
//+------------------------------------------------------------------+
bool CLLMConnector::GetBatchPredictions(string &symbols[], const ENUM_TIMEFRAMES timeframe, SPrediction &predictions[])
{
   int count = ArraySize(symbols);
   ArrayResize(predictions, count);

   bool allSuccess = true;
   for(int i = 0; i < count; i++)
   {
      if(!GetPrediction(symbols[i], timeframe, predictions[i]))
      {
         allSuccess = false;
      }
   }

   return allSuccess;
}

//+------------------------------------------------------------------+
//| Get news sentiment                                                |
//+------------------------------------------------------------------+
bool CLLMConnector::GetNewsSentiment(const string symbol, double &sentiment, string &summary)
{
   if(!m_Connected)
      return false;

   string url = m_APIUrl + "/api/sentiment/" + symbol;
   string headers = "Content-Type: application/json\r\n";
   if(m_APIKey != "")
      headers += "Authorization: Bearer " + m_APIKey + "\r\n";

   char post[];
   char result[];
   string resultHeaders;

   int res = WebRequest(
      "GET",
      url,
      headers,
      m_Timeout,
      post,
      result,
      resultHeaders
   );

   if(res != 200)
      return false;

   string response = CharArrayToString(result);

   //--- Parse sentiment
   int sentPos = StringFind(response, "\"sentiment\":");
   if(sentPos >= 0)
   {
      string sentStr = StringSubstr(response, sentPos + 12, 10);
      sentiment = StringToDouble(sentStr);
   }

   //--- Parse summary
   int sumPos = StringFind(response, "\"summary\":\"");
   if(sumPos >= 0)
   {
      int endPos = StringFind(response, "\"", sumPos + 11);
      if(endPos > sumPos)
      {
         summary = StringSubstr(response, sumPos + 11, endPos - sumPos - 11);
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get market analysis                                               |
//+------------------------------------------------------------------+
bool CLLMConnector::GetMarketAnalysis(const string symbol, string &analysis)
{
   if(!m_Connected)
      return false;

   string url = m_APIUrl + "/api/analysis/" + symbol;
   string headers = "Content-Type: application/json\r\n";
   if(m_APIKey != "")
      headers += "Authorization: Bearer " + m_APIKey + "\r\n";

   char post[];
   char result[];
   string resultHeaders;

   int res = WebRequest(
      "GET",
      url,
      headers,
      m_Timeout,
      post,
      result,
      resultHeaders
   );

   if(res != 200)
      return false;

   string response = CharArrayToString(result);

   //--- Parse analysis
   int analPos = StringFind(response, "\"analysis\":\"");
   if(analPos >= 0)
   {
      int endPos = StringFind(response, "\"", analPos + 12);
      if(endPos > analPos)
      {
         analysis = StringSubstr(response, analPos + 12, endPos - analPos - 12);
      }
   }

   return true;
}

//+------------------------------------------------------------------+
