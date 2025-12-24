# Trading Assistant EA - AI-Powered Trading Signals

An intelligent Expert Advisor for MetaTrader 5 that combines LLM (Large Language Model) analysis with machine learning predictions for automated trading.

## Features

- **AI-Powered Predictions**: Uses FinBot LLM for market analysis and signal generation
- **ML Technical Analysis**: Pattern recognition, trend analysis, and momentum indicators
- **Sentiment Analysis**: Real-time news and market sentiment integration
- **Risk Management**: Advanced position sizing and drawdown control
- **Web Dashboard**: Modern web interface for monitoring and configuration
- **Multi-Asset Support**: Forex, Crypto, Commodities, and Indices

## Architecture

```
TradingAssistant/
├── TradingAssistantEA.mq5    # Main EA file
├── LLMConnector.mqh          # API connector for LLM predictions
├── PredictionSignal.mqh      # Local signal generation
├── RiskManager.mqh           # Risk and money management
└── README.md                 # This file

backend/
├── main.py                   # FastAPI server
├── prediction_model.py       # ML prediction engine
├── finbot.py                 # LLM integration
├── sentiment_analyzer.py     # Sentiment analysis
├── news_fetcher.py          # News aggregation
└── requirements.txt          # Python dependencies

website/
├── index.html               # Dashboard UI
├── styles.css               # Styling
└── app.js                   # Frontend logic
```

## Installation

### 1. MetaTrader 5 Setup

1. Copy all files from `TradingAssistant/` to your MT5 `Experts` folder:
   ```
   C:\Users\[User]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Experts\TradingAssistant\
   ```

2. Copy the EasyMQL framework to `Include`:
   ```
   C:\Users\[User]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Include\
   ```

3. Add the API URL to MT5 allowed URLs:
   - Tools → Options → Expert Advisors
   - Check "Allow WebRequest for listed URL"
   - Add: `http://localhost:8000`

4. Compile `TradingAssistantEA.mq5` in MetaEditor

### 2. Backend Setup

```bash
# Navigate to backend directory
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Start the server
python main.py
```

The API will be available at `http://localhost:8000`

### 3. Web Dashboard

Open `website/index.html` in a browser, or serve it with:

```bash
cd website
python -m http.server 3000
```

Access the dashboard at `http://localhost:3000`

## Configuration

### EA Input Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| InpAPIUrl | Prediction API URL | http://localhost:8000 |
| InpAPIKey | API authentication key | (empty) |
| InpRiskPercent | Risk per trade (%) | 1.0 |
| InpMaxDrawdown | Maximum drawdown (%) | 10.0 |
| InpMaxPositions | Max simultaneous positions | 3 |
| InpMinConfidence | Minimum prediction confidence | 0.7 |
| InpStopLoss | Default stop loss (pips) | 50 |
| InpTakeProfit | Default take profit (pips) | 100 |

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | API health check |
| `/api/predict` | POST | Get trading prediction |
| `/api/sentiment/{symbol}` | GET | Get sentiment analysis |
| `/api/analysis/{symbol}` | GET | Get market analysis |
| `/api/symbols` | GET | List supported symbols |

## Usage

### Running the EA

1. Attach `TradingAssistantEA` to a chart
2. Configure the input parameters
3. Enable Auto Trading
4. The EA will:
   - Fetch predictions from the API
   - Fall back to local analysis if API unavailable
   - Execute trades based on signals
   - Manage positions with trailing stops

### Dashboard Features

- **Real-time Signals**: View current trading signals
- **Technical Indicators**: RSI, MACD, MA Cross status
- **Sentiment Analysis**: Market mood visualization
- **Signal History**: Track all generated signals
- **AI Analysis**: Generate comprehensive market analysis
- **News Feed**: Latest market news with sentiment
- **Economic Calendar**: Upcoming market events

## Signal Generation

### LLM Analysis (via API)
- Market context understanding
- News sentiment integration
- Support/resistance identification
- Risk assessment

### ML Prediction
- LSTM price prediction
- Pattern recognition (engulfing, hammer, doji, etc.)
- Technical indicator analysis
- Trend and momentum scoring

### Local Fallback
When the API is unavailable, the EA uses:
- Moving average crossovers
- RSI divergence
- MACD signals
- Candlestick patterns

## Risk Management

- **Position Sizing**: Risk-based lot calculation
- **Drawdown Control**: Trading stops when limit reached
- **Max Positions**: Prevents over-exposure
- **Trailing Stops**: Protects profits

## API Response Format

```json
{
    "direction": 1,
    "confidence": 0.85,
    "sentiment": 0.3,
    "price_target": 1.2345,
    "stop_loss": 1.2300,
    "take_profit": 1.2400,
    "reason": "Strong bullish momentum with positive sentiment",
    "news_impact": "Positive economic data supports upward bias"
}
```

Direction values:
- `1` = BUY
- `-1` = SELL
- `0` = HOLD

## Extending the System

### Adding New Indicators

Edit `PredictionSignal.mqh`:
```cpp
double CPredictionSignal::AnalyzeCustomIndicator(...)
{
    // Your indicator logic
}
```

### Custom LLM Integration

Edit `backend/finbot.py`:
```python
# Add your LLM API key
import openai
openai.api_key = "your-key"

# Or use local Llama
from llama_cpp import Llama
model = Llama(model_path="path/to/model.gguf")
```

### Adding News Sources

Edit `backend/news_fetcher.py`:
```python
def _fetch_from_custom_source(self):
    # Add your news API integration
    pass
```

## Disclaimer

This software is for educational purposes only. Trading financial instruments carries significant risk. Always:
- Test on demo accounts first
- Use proper risk management
- Never risk more than you can afford to lose
- Past performance doesn't guarantee future results

## License

MIT License - See LICENSE file for details

## Credits

- Built on EasyMQL Framework
- Inspired by [FinGPT](https://github.com/AI4Finance-Foundation/FinGPT)
- ML concepts from [Stock-Prediction-Models](https://github.com/huseinzol05/Stock-Prediction-Models)
