"""
Trading Assistant API Backend
FastAPI server for LLM-powered trading predictions
"""

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List
import uvicorn
from datetime import datetime
import logging

from prediction_model import PredictionModel
from finbot import FinBot
from sentiment_analyzer import SentimentAnalyzer
from news_fetcher import NewsFetcher

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Trading Assistant API",
    description="AI-powered trading predictions using LLM and ML models",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize components
prediction_model = PredictionModel()
finbot = FinBot()
sentiment_analyzer = SentimentAnalyzer()
news_fetcher = NewsFetcher()

# Request/Response Models
class MarketData(BaseModel):
    open: List[float]
    high: List[float]
    low: List[float]
    close: List[float]
    volume: List[int]
    current_ask: Optional[float] = None
    current_bid: Optional[float] = None
    spread: Optional[int] = None

class PredictionRequest(BaseModel):
    symbol: str
    timeframe: str
    timestamp: int
    market_data: MarketData

class PredictionResponse(BaseModel):
    direction: int  # 1 = BUY, -1 = SELL, 0 = HOLD
    confidence: float
    sentiment: float
    price_target: float
    stop_loss: float
    take_profit: float
    reason: str
    news_impact: str

class SentimentResponse(BaseModel):
    sentiment: float
    summary: str

class AnalysisResponse(BaseModel):
    analysis: str
    key_levels: dict
    trend: str
    recommendation: str

class HealthResponse(BaseModel):
    status: str
    version: str
    models_loaded: bool
    timestamp: str

# API Key validation (optional)
async def verify_api_key(authorization: Optional[str] = Header(None)):
    # For development, skip validation if no key provided
    if authorization is None:
        return True
    # In production, validate the API key
    # if authorization != f"Bearer {EXPECTED_API_KEY}":
    #     raise HTTPException(status_code=401, detail="Invalid API key")
    return True

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for the API"""
    return HealthResponse(
        status="healthy",
        version="1.0.0",
        models_loaded=prediction_model.is_loaded(),
        timestamp=datetime.now().isoformat()
    )

@app.post("/api/predict", response_model=PredictionResponse)
async def get_prediction(
    request: PredictionRequest,
    authorized: bool = Depends(verify_api_key)
):
    """
    Generate trading prediction based on market data and LLM analysis
    """
    try:
        logger.info(f"Prediction request for {request.symbol} on {request.timeframe}")

        # Convert market data to numpy arrays for processing
        market_data = {
            'open': request.market_data.open,
            'high': request.market_data.high,
            'low': request.market_data.low,
            'close': request.market_data.close,
            'volume': request.market_data.volume
        }

        # Get ML prediction
        ml_prediction = prediction_model.predict(
            symbol=request.symbol,
            timeframe=request.timeframe,
            data=market_data
        )

        # Get LLM analysis
        llm_analysis = finbot.analyze(
            symbol=request.symbol,
            market_data=market_data,
            ml_prediction=ml_prediction
        )

        # Get sentiment analysis
        sentiment = sentiment_analyzer.analyze(request.symbol)

        # Get news impact
        news = news_fetcher.get_latest_news(request.symbol)
        news_impact = sentiment_analyzer.analyze_news(news)

        # Combine predictions
        final_prediction = combine_predictions(
            ml_prediction=ml_prediction,
            llm_analysis=llm_analysis,
            sentiment=sentiment
        )

        # Calculate price targets
        current_price = request.market_data.close[-1] if request.market_data.close else 0
        atr = calculate_atr(market_data)

        if final_prediction['direction'] == 1:  # BUY
            price_target = current_price + (atr * 2)
            stop_loss = current_price - atr
            take_profit = current_price + (atr * 3)
        elif final_prediction['direction'] == -1:  # SELL
            price_target = current_price - (atr * 2)
            stop_loss = current_price + atr
            take_profit = current_price - (atr * 3)
        else:
            price_target = current_price
            stop_loss = current_price
            take_profit = current_price

        return PredictionResponse(
            direction=final_prediction['direction'],
            confidence=final_prediction['confidence'],
            sentiment=sentiment['score'],
            price_target=round(price_target, 5),
            stop_loss=round(stop_loss, 5),
            take_profit=round(take_profit, 5),
            reason=llm_analysis['reason'],
            news_impact=news_impact['summary']
        )

    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/sentiment/{symbol}", response_model=SentimentResponse)
async def get_sentiment(
    symbol: str,
    authorized: bool = Depends(verify_api_key)
):
    """Get sentiment analysis for a symbol"""
    try:
        sentiment = sentiment_analyzer.analyze(symbol)
        news = news_fetcher.get_latest_news(symbol)
        news_analysis = sentiment_analyzer.analyze_news(news)

        return SentimentResponse(
            sentiment=sentiment['score'],
            summary=news_analysis['summary']
        )
    except Exception as e:
        logger.error(f"Sentiment error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/analysis/{symbol}", response_model=AnalysisResponse)
async def get_analysis(
    symbol: str,
    authorized: bool = Depends(verify_api_key)
):
    """Get comprehensive market analysis for a symbol"""
    try:
        analysis = finbot.get_market_analysis(symbol)

        return AnalysisResponse(
            analysis=analysis['text'],
            key_levels=analysis['key_levels'],
            trend=analysis['trend'],
            recommendation=analysis['recommendation']
        )
    except Exception as e:
        logger.error(f"Analysis error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/symbols")
async def get_symbols():
    """Get list of supported trading symbols"""
    return {
        "forex": [
            "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD",
            "USDCAD", "NZDUSD", "EURJPY", "GBPJPY", "EURGBP"
        ],
        "indices": [
            "US30", "US500", "US100", "GER40", "UK100", "JP225"
        ],
        "commodities": [
            "XAUUSD", "XAGUSD", "USOIL", "UKOIL"
        ],
        "crypto": [
            "BTCUSD", "ETHUSD", "LTCUSD"
        ]
    }

@app.get("/api/stats")
async def get_stats():
    """Get API usage statistics"""
    return {
        "total_predictions": prediction_model.get_stats()['total'],
        "accuracy": prediction_model.get_stats()['accuracy'],
        "last_updated": datetime.now().isoformat()
    }

def combine_predictions(ml_prediction: dict, llm_analysis: dict, sentiment: dict) -> dict:
    """
    Combine ML prediction, LLM analysis, and sentiment into final prediction
    """
    # Weights for different sources
    ml_weight = 0.4
    llm_weight = 0.4
    sentiment_weight = 0.2

    # Calculate weighted direction
    ml_dir = ml_prediction.get('direction', 0)
    llm_dir = llm_analysis.get('direction', 0)
    sent_dir = 1 if sentiment['score'] > 0.1 else (-1 if sentiment['score'] < -0.1 else 0)

    weighted_direction = (
        ml_dir * ml_weight +
        llm_dir * llm_weight +
        sent_dir * sentiment_weight
    )

    # Determine final direction
    if weighted_direction > 0.3:
        direction = 1
    elif weighted_direction < -0.3:
        direction = -1
    else:
        direction = 0

    # Calculate confidence
    ml_conf = ml_prediction.get('confidence', 0.5)
    llm_conf = llm_analysis.get('confidence', 0.5)

    # Higher confidence if sources agree
    agreement = (
        (ml_dir > 0 and llm_dir > 0) or
        (ml_dir < 0 and llm_dir < 0)
    )

    base_confidence = (ml_conf * ml_weight + llm_conf * (ml_weight + llm_weight)) / (ml_weight + llm_weight)

    if agreement:
        confidence = min(base_confidence * 1.2, 1.0)
    else:
        confidence = base_confidence * 0.8

    return {
        'direction': direction,
        'confidence': round(confidence, 3)
    }

def calculate_atr(market_data: dict, period: int = 14) -> float:
    """Calculate Average True Range"""
    highs = market_data['high']
    lows = market_data['low']
    closes = market_data['close']

    if len(closes) < period + 1:
        return 0.0

    tr_values = []
    for i in range(1, len(closes)):
        high_low = highs[i] - lows[i]
        high_close = abs(highs[i] - closes[i-1])
        low_close = abs(lows[i] - closes[i-1])
        tr = max(high_low, high_close, low_close)
        tr_values.append(tr)

    if len(tr_values) < period:
        return sum(tr_values) / len(tr_values) if tr_values else 0.0

    return sum(tr_values[-period:]) / period

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
