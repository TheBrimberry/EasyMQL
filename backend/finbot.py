"""
FinBot - LLM-powered Financial Analysis Bot
Uses Llama-based models for market analysis and trading insights
"""

import os
import logging
from typing import Dict, List, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class MarketContext:
    """Market context for LLM analysis"""
    symbol: str
    trend: str
    volatility: str
    support_levels: List[float]
    resistance_levels: List[float]
    key_events: List[str]

class FinBot:
    """
    Financial Analysis Bot powered by LLM
    Provides market analysis, trading insights, and signal confirmation
    """

    def __init__(self, model_name: str = "llama-finbot"):
        self.model_name = model_name
        self.is_initialized = False
        self._initialize()

    def _initialize(self):
        """Initialize the LLM model"""
        try:
            # In production, initialize actual LLM here
            # Options:
            # 1. Local Llama model via llama-cpp-python
            # 2. OpenAI API
            # 3. Anthropic Claude API
            # 4. HuggingFace transformers

            # Example with environment variable for API
            # self.api_key = os.getenv('OPENAI_API_KEY') or os.getenv('ANTHROPIC_API_KEY')

            self.is_initialized = True
            logger.info(f"FinBot initialized with model: {self.model_name}")
        except Exception as e:
            logger.error(f"Failed to initialize FinBot: {e}")
            self.is_initialized = False

    def analyze(self, symbol: str, market_data: Dict, ml_prediction: Dict) -> Dict:
        """
        Analyze market data and provide trading insights

        Args:
            symbol: Trading symbol
            market_data: OHLCV data
            ml_prediction: ML model prediction

        Returns:
            Analysis with direction, confidence, and reasoning
        """
        try:
            # Extract key information from market data
            closes = market_data['close']
            highs = market_data['high']
            lows = market_data['low']

            # Calculate key levels
            support, resistance = self._calculate_key_levels(highs, lows, closes)

            # Determine trend
            trend = self._determine_trend(closes)

            # Calculate volatility state
            volatility = self._calculate_volatility_state(closes)

            # Build market context
            context = MarketContext(
                symbol=symbol,
                trend=trend,
                volatility=volatility,
                support_levels=support,
                resistance_levels=resistance,
                key_events=[]
            )

            # Generate LLM analysis (simulated for now)
            analysis = self._generate_analysis(context, ml_prediction)

            return analysis

        except Exception as e:
            logger.error(f"Analysis error: {e}")
            return {
                'direction': 0,
                'confidence': 0.5,
                'reason': f"Analysis unavailable: {str(e)}"
            }

    def _calculate_key_levels(self, highs: List, lows: List, closes: List) -> tuple:
        """Calculate support and resistance levels"""
        import numpy as np

        if len(closes) < 20:
            return [closes[-1] * 0.99], [closes[-1] * 1.01]

        # Find swing highs and lows
        swing_highs = []
        swing_lows = []

        for i in range(2, len(highs) - 2):
            # Swing high
            if highs[i] > highs[i-1] and highs[i] > highs[i-2] and \
               highs[i] > highs[i+1] and highs[i] > highs[i+2]:
                swing_highs.append(highs[i])

            # Swing low
            if lows[i] < lows[i-1] and lows[i] < lows[i-2] and \
               lows[i] < lows[i+1] and lows[i] < lows[i+2]:
                swing_lows.append(lows[i])

        # Get most recent significant levels
        current_price = closes[-1]

        resistance = sorted([h for h in swing_highs if h > current_price])[:3]
        support = sorted([l for l in swing_lows if l < current_price], reverse=True)[:3]

        if not resistance:
            resistance = [current_price * 1.01, current_price * 1.02]
        if not support:
            support = [current_price * 0.99, current_price * 0.98]

        return support, resistance

    def _determine_trend(self, closes: List) -> str:
        """Determine current trend"""
        import numpy as np

        if len(closes) < 50:
            return "neutral"

        # Calculate short and long term averages
        short_ma = np.mean(closes[-20:])
        long_ma = np.mean(closes[-50:])
        current = closes[-1]

        # Calculate trend slope
        short_slope = (closes[-1] - closes[-20]) / closes[-20] * 100

        if current > short_ma > long_ma and short_slope > 0.5:
            return "strong_bullish"
        elif current > short_ma and short_slope > 0:
            return "bullish"
        elif current < short_ma < long_ma and short_slope < -0.5:
            return "strong_bearish"
        elif current < short_ma and short_slope < 0:
            return "bearish"
        else:
            return "neutral"

    def _calculate_volatility_state(self, closes: List) -> str:
        """Calculate volatility state"""
        import numpy as np

        if len(closes) < 20:
            return "normal"

        # Calculate standard deviation of returns
        returns = np.diff(closes) / closes[:-1]
        volatility = np.std(returns) * 100

        if volatility > 2.0:
            return "high"
        elif volatility < 0.5:
            return "low"
        else:
            return "normal"

    def _generate_analysis(self, context: MarketContext, ml_prediction: Dict) -> Dict:
        """
        Generate LLM-style analysis
        In production, this would call the actual LLM API
        """
        # Build reasoning based on context
        reasons = []
        direction = 0
        confidence = 0.5

        # Trend analysis
        if context.trend in ["strong_bullish", "bullish"]:
            reasons.append(f"{context.symbol} showing {context.trend.replace('_', ' ')} trend")
            direction += 0.5 if context.trend == "strong_bullish" else 0.3
        elif context.trend in ["strong_bearish", "bearish"]:
            reasons.append(f"{context.symbol} showing {context.trend.replace('_', ' ')} trend")
            direction -= 0.5 if context.trend == "strong_bearish" else 0.3
        else:
            reasons.append(f"{context.symbol} in consolidation phase")

        # Volatility consideration
        if context.volatility == "high":
            reasons.append("High volatility detected - exercise caution")
            confidence *= 0.8
        elif context.volatility == "low":
            reasons.append("Low volatility environment")
            confidence *= 1.1

        # Key levels
        if context.support_levels:
            reasons.append(f"Key support at {context.support_levels[0]:.5f}")
        if context.resistance_levels:
            reasons.append(f"Key resistance at {context.resistance_levels[0]:.5f}")

        # ML prediction integration
        ml_dir = ml_prediction.get('direction', 0)
        ml_conf = ml_prediction.get('confidence', 0.5)

        if ml_dir != 0:
            ml_signal = "bullish" if ml_dir > 0 else "bearish"
            reasons.append(f"ML model signals {ml_signal} with {ml_conf*100:.1f}% confidence")

            # Agreement boosts confidence
            if (direction > 0 and ml_dir > 0) or (direction < 0 and ml_dir < 0):
                confidence = min(confidence * 1.2, 0.95)
                reasons.append("Technical and ML signals aligned")
            else:
                confidence *= 0.8
                reasons.append("Mixed signals between technical and ML analysis")

        # Final direction
        if direction > 0.3:
            final_direction = 1
        elif direction < -0.3:
            final_direction = -1
        else:
            final_direction = 0

        # Build final reason string
        reason_text = ". ".join(reasons)

        return {
            'direction': final_direction,
            'confidence': round(min(max(confidence, 0.1), 0.95), 3),
            'reason': reason_text,
            'trend': context.trend,
            'volatility': context.volatility,
            'support': context.support_levels,
            'resistance': context.resistance_levels
        }

    def get_market_analysis(self, symbol: str) -> Dict:
        """
        Get comprehensive market analysis for a symbol
        """
        # In production, this would fetch live data and run full analysis
        return {
            'text': f"Comprehensive analysis for {symbol}. Market conditions are currently stable with moderate volatility. Key economic events may impact price action.",
            'key_levels': {
                'support': [1.0800, 1.0750, 1.0700],
                'resistance': [1.0900, 1.0950, 1.1000]
            },
            'trend': 'neutral',
            'recommendation': 'Wait for clear breakout before entering positions'
        }

    def generate_trade_idea(self, symbol: str, timeframe: str) -> Dict:
        """
        Generate a trade idea with entry, SL, and TP
        """
        return {
            'symbol': symbol,
            'timeframe': timeframe,
            'direction': 'BUY',
            'entry': 1.0850,
            'stop_loss': 1.0800,
            'take_profit': 1.0950,
            'risk_reward': 2.0,
            'reasoning': 'Price approaching key support with bullish divergence on RSI'
        }

    def chat(self, message: str, context: Optional[Dict] = None) -> str:
        """
        Chat interface for market-related questions
        """
        # In production, this would use the LLM for conversational responses
        return f"Based on current market conditions, I would recommend careful analysis of {context.get('symbol', 'the market') if context else 'the market'} before making trading decisions."
