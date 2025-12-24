//+------------------------------------------------------------------+
//|                                                 RiskManager.mqh   |
//|                         Advanced Risk Management for Trading      |
//|                         Position sizing, drawdown control         |
//+------------------------------------------------------------------+
#property copyright "EasyMQL Trading Assistant"
#property link      "https://github.com/TheBrimberry/EasyMQL"

#include "../trade/AccountInfo.mqh"

//+------------------------------------------------------------------+
//| Risk Manager Class                                                |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double            m_RiskPercent;        // Risk per trade %
   double            m_MaxDrawdown;        // Maximum allowed drawdown %
   int               m_MaxPositions;       // Maximum simultaneous positions
   double            m_StopLoss;           // Default stop loss in pips
   double            m_TakeProfit;         // Default take profit in pips

   double            m_InitialBalance;     // Balance at start
   double            m_PeakBalance;        // Highest balance reached
   double            m_CurrentDrawdown;    // Current drawdown %

   int               m_MagicNumber;        // EA magic number for filtering

   //--- Statistics
   int               m_TotalTrades;
   int               m_WinningTrades;
   int               m_LosingTrades;
   double            m_TotalProfit;
   double            m_TotalLoss;

public:
                     CRiskManager();
                    ~CRiskManager();

   //--- Initialization
   void              Initialize(double riskPercent, double maxDrawdown, int maxPositions);
   void              SetStopLoss(double sl) { m_StopLoss = sl; }
   void              SetTakeProfit(double tp) { m_TakeProfit = tp; }
   void              SetMagicNumber(int magic) { m_MagicNumber = magic; }

   //--- Update and monitoring
   void              Update();
   bool              IsDrawdownExceeded();
   int               GetOpenPositions();
   double            GetCurrentDrawdown() { return m_CurrentDrawdown; }

   //--- Position sizing
   double            CalculateLotSize(const string symbol, double stopLossPips);
   double            CalculateLotSizeRisk(const string symbol, double riskAmount, double stopLossPips);
   double            AdjustLotSize(double lots, const string symbol);

   //--- Risk assessment
   double            GetMaxLotSize(const string symbol);
   double            GetMinLotSize(const string symbol);
   double            GetRiskAmount();
   double            GetMarginRequired(const string symbol, double lots);
   bool              HasSufficientMargin(const string symbol, double lots);

   //--- Statistics
   double            GetWinRate();
   double            GetProfitFactor();
   double            GetAverageWin();
   double            GetAverageLoss();
   void              RecordTrade(double profit);

   //--- Position management
   double            GetTotalExposure();
   double            GetSymbolExposure(const string symbol);
   bool              IsMaxExposureReached();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
   m_RiskPercent = 1.0;
   m_MaxDrawdown = 10.0;
   m_MaxPositions = 3;
   m_StopLoss = 50.0;
   m_TakeProfit = 100.0;
   m_MagicNumber = 0;

   m_InitialBalance = 0;
   m_PeakBalance = 0;
   m_CurrentDrawdown = 0;

   m_TotalTrades = 0;
   m_WinningTrades = 0;
   m_LosingTrades = 0;
   m_TotalProfit = 0;
   m_TotalLoss = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
}

//+------------------------------------------------------------------+
//| Initialize risk manager                                           |
//+------------------------------------------------------------------+
void CRiskManager::Initialize(double riskPercent, double maxDrawdown, int maxPositions)
{
   m_RiskPercent = riskPercent;
   m_MaxDrawdown = maxDrawdown;
   m_MaxPositions = maxPositions;

   m_InitialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_PeakBalance = m_InitialBalance;
   m_CurrentDrawdown = 0;

   Print("Risk Manager initialized:");
   Print("  Risk per trade: ", m_RiskPercent, "%");
   Print("  Max drawdown: ", m_MaxDrawdown, "%");
   Print("  Max positions: ", m_MaxPositions);
   Print("  Initial balance: ", m_InitialBalance);
}

//+------------------------------------------------------------------+
//| Update risk metrics                                               |
//+------------------------------------------------------------------+
void CRiskManager::Update()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   //--- Update peak balance
   if(currentBalance > m_PeakBalance)
   {
      m_PeakBalance = currentBalance;
   }

   //--- Calculate current drawdown
   if(m_PeakBalance > 0)
   {
      m_CurrentDrawdown = (m_PeakBalance - currentEquity) / m_PeakBalance * 100;
   }
}

//+------------------------------------------------------------------+
//| Check if drawdown limit exceeded                                  |
//+------------------------------------------------------------------+
bool CRiskManager::IsDrawdownExceeded()
{
   return m_CurrentDrawdown >= m_MaxDrawdown;
}

//+------------------------------------------------------------------+
//| Get count of open positions                                       |
//+------------------------------------------------------------------+
int CRiskManager::GetOpenPositions()
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(m_MagicNumber > 0 && PositionGetInteger(POSITION_MAGIC) != m_MagicNumber)
         continue;

      count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(const string symbol, double stopLossPips)
{
   if(stopLossPips <= 0)
   {
      stopLossPips = m_StopLoss;
   }

   double riskAmount = GetRiskAmount();
   return CalculateLotSizeRisk(symbol, riskAmount, stopLossPips);
}

//+------------------------------------------------------------------+
//| Calculate lot size for specific risk amount                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSizeRisk(const string symbol, double riskAmount, double stopLossPips)
{
   //--- Get symbol info
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(tickSize == 0 || tickValue == 0 || point == 0)
   {
      Print("Error getting symbol info for ", symbol);
      return 0;
   }

   //--- Convert pips to price
   double stopLossPrice = stopLossPips * point * 10;  // Assuming 5-digit broker

   //--- Calculate pip value
   double pipValue = tickValue * (point * 10 / tickSize);

   //--- Calculate lot size
   double lots = 0;
   if(stopLossPips > 0 && pipValue > 0)
   {
      lots = riskAmount / (stopLossPips * pipValue);
   }

   //--- Adjust to valid lot size
   lots = AdjustLotSize(lots, symbol);

   return lots;
}

//+------------------------------------------------------------------+
//| Adjust lot size to valid value                                    |
//+------------------------------------------------------------------+
double CRiskManager::AdjustLotSize(double lots, const string symbol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   //--- Check minimum
   if(lots < minLot)
      lots = minLot;

   //--- Check maximum
   if(lots > maxLot)
      lots = maxLot;

   //--- Round to lot step
   lots = MathFloor(lots / lotStep) * lotStep;

   //--- Normalize
   lots = NormalizeDouble(lots, 2);

   return lots;
}

//+------------------------------------------------------------------+
//| Get risk amount based on balance                                  |
//+------------------------------------------------------------------+
double CRiskManager::GetRiskAmount()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   return balance * m_RiskPercent / 100;
}

//+------------------------------------------------------------------+
//| Get maximum lot size for symbol                                   |
//+------------------------------------------------------------------+
double CRiskManager::GetMaxLotSize(const string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
}

//+------------------------------------------------------------------+
//| Get minimum lot size for symbol                                   |
//+------------------------------------------------------------------+
double CRiskManager::GetMinLotSize(const string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
}

//+------------------------------------------------------------------+
//| Get margin required for position                                  |
//+------------------------------------------------------------------+
double CRiskManager::GetMarginRequired(const string symbol, double lots)
{
   double margin = 0;

   if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, lots,
      SymbolInfoDouble(symbol, SYMBOL_ASK), margin))
   {
      return 0;
   }

   return margin;
}

//+------------------------------------------------------------------+
//| Check if sufficient margin available                              |
//+------------------------------------------------------------------+
bool CRiskManager::HasSufficientMargin(const string symbol, double lots)
{
   double marginRequired = GetMarginRequired(symbol, lots);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   //--- Require at least 20% buffer
   return freeMargin > marginRequired * 1.2;
}

//+------------------------------------------------------------------+
//| Get win rate                                                      |
//+------------------------------------------------------------------+
double CRiskManager::GetWinRate()
{
   if(m_TotalTrades == 0)
      return 0;

   return (double)m_WinningTrades / m_TotalTrades * 100;
}

//+------------------------------------------------------------------+
//| Get profit factor                                                 |
//+------------------------------------------------------------------+
double CRiskManager::GetProfitFactor()
{
   if(m_TotalLoss == 0)
      return m_TotalProfit > 0 ? 999 : 0;

   return m_TotalProfit / MathAbs(m_TotalLoss);
}

//+------------------------------------------------------------------+
//| Get average winning trade                                         |
//+------------------------------------------------------------------+
double CRiskManager::GetAverageWin()
{
   if(m_WinningTrades == 0)
      return 0;

   return m_TotalProfit / m_WinningTrades;
}

//+------------------------------------------------------------------+
//| Get average losing trade                                          |
//+------------------------------------------------------------------+
double CRiskManager::GetAverageLoss()
{
   if(m_LosingTrades == 0)
      return 0;

   return m_TotalLoss / m_LosingTrades;
}

//+------------------------------------------------------------------+
//| Record trade result                                               |
//+------------------------------------------------------------------+
void CRiskManager::RecordTrade(double profit)
{
   m_TotalTrades++;

   if(profit > 0)
   {
      m_WinningTrades++;
      m_TotalProfit += profit;
   }
   else if(profit < 0)
   {
      m_LosingTrades++;
      m_TotalLoss += MathAbs(profit);
   }
}

//+------------------------------------------------------------------+
//| Get total exposure across all positions                           |
//+------------------------------------------------------------------+
double CRiskManager::GetTotalExposure()
{
   double totalExposure = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(m_MagicNumber > 0 && PositionGetInteger(POSITION_MAGIC) != m_MagicNumber)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_CURRENT);
      double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

      totalExposure += volume * price * contractSize;
   }

   return totalExposure;
}

//+------------------------------------------------------------------+
//| Get exposure for specific symbol                                  |
//+------------------------------------------------------------------+
double CRiskManager::GetSymbolExposure(const string symbol)
{
   double exposure = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if(m_MagicNumber > 0 && PositionGetInteger(POSITION_MAGIC) != m_MagicNumber)
         continue;

      double volume = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_CURRENT);
      double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

      exposure += volume * price * contractSize;
   }

   return exposure;
}

//+------------------------------------------------------------------+
//| Check if maximum exposure is reached                              |
//+------------------------------------------------------------------+
bool CRiskManager::IsMaxExposureReached()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double exposure = GetTotalExposure();

   //--- Max exposure is 5x balance (leverage consideration)
   return exposure > balance * 5;
}

//+------------------------------------------------------------------+
