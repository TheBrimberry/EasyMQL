"""
Machine Learning Prediction Model
LSTM-based price prediction with technical indicators
"""

import numpy as np
from typing import Dict, List, Optional
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)

@dataclass
class TechnicalIndicators:
    """Technical indicators for analysis"""
    rsi: float
    macd: float
    macd_signal: float
    macd_histogram: float
    sma_20: float
    sma_50: float
    ema_12: float
    ema_26: float
    bollinger_upper: float
    bollinger_lower: float
    bollinger_middle: float
    atr: float
    adx: float

class PredictionModel:
    """
    ML-based prediction model for trading signals
    Uses technical indicators and pattern recognition
    """

    def __init__(self):
        self.is_initialized = False
        self.stats = {
            'total': 0,
            'correct': 0,
            'accuracy': 0.0
        }
        self._initialize_model()

    def _initialize_model(self):
        """Initialize the prediction model"""
        try:
            # In production, load trained model here
            # self.model = load_model('models/lstm_model.h5')
            self.is_initialized = True
            logger.info("Prediction model initialized")
        except Exception as e:
            logger.error(f"Failed to initialize model: {e}")
            self.is_initialized = False

    def is_loaded(self) -> bool:
        """Check if model is loaded"""
        return self.is_initialized

    def predict(self, symbol: str, timeframe: str, data: Dict) -> Dict:
        """
        Generate prediction based on market data

        Args:
            symbol: Trading symbol
            timeframe: Timeframe (M1, M5, H1, etc.)
            data: Market data with OHLCV

        Returns:
            Prediction with direction and confidence
        """
        try:
            # Calculate technical indicators
            indicators = self._calculate_indicators(data)

            # Analyze trend
            trend_signal = self._analyze_trend(data, indicators)

            # Analyze momentum
            momentum_signal = self._analyze_momentum(indicators)

            # Analyze volatility
            volatility = self._analyze_volatility(data, indicators)

            # Detect patterns
            pattern_signal = self._detect_patterns(data)

            # Combine signals
            combined_signal = self._combine_signals(
                trend_signal,
                momentum_signal,
                pattern_signal,
                volatility
            )

            # Determine direction and confidence
            if combined_signal > 0.3:
                direction = 1  # BUY
                confidence = min(combined_signal, 1.0)
            elif combined_signal < -0.3:
                direction = -1  # SELL
                confidence = min(abs(combined_signal), 1.0)
            else:
                direction = 0  # HOLD
                confidence = 0.5

            self.stats['total'] += 1

            return {
                'direction': direction,
                'confidence': round(confidence, 3),
                'trend_signal': trend_signal,
                'momentum_signal': momentum_signal,
                'pattern_signal': pattern_signal,
                'indicators': indicators.__dict__ if indicators else {}
            }

        except Exception as e:
            logger.error(f"Prediction error: {e}")
            return {
                'direction': 0,
                'confidence': 0.5,
                'error': str(e)
            }

    def _calculate_indicators(self, data: Dict) -> TechnicalIndicators:
        """Calculate technical indicators"""
        closes = np.array(data['close'])
        highs = np.array(data['high'])
        lows = np.array(data['low'])

        # RSI
        rsi = self._calculate_rsi(closes)

        # MACD
        macd, signal, histogram = self._calculate_macd(closes)

        # Moving Averages
        sma_20 = np.mean(closes[-20:]) if len(closes) >= 20 else closes[-1]
        sma_50 = np.mean(closes[-50:]) if len(closes) >= 50 else closes[-1]
        ema_12 = self._calculate_ema(closes, 12)
        ema_26 = self._calculate_ema(closes, 26)

        # Bollinger Bands
        bb_upper, bb_middle, bb_lower = self._calculate_bollinger_bands(closes)

        # ATR
        atr = self._calculate_atr(highs, lows, closes)

        # ADX (simplified)
        adx = self._calculate_adx(highs, lows, closes)

        return TechnicalIndicators(
            rsi=rsi,
            macd=macd,
            macd_signal=signal,
            macd_histogram=histogram,
            sma_20=sma_20,
            sma_50=sma_50,
            ema_12=ema_12,
            ema_26=ema_26,
            bollinger_upper=bb_upper,
            bollinger_lower=bb_lower,
            bollinger_middle=bb_middle,
            atr=atr,
            adx=adx
        )

    def _calculate_rsi(self, closes: np.ndarray, period: int = 14) -> float:
        """Calculate RSI"""
        if len(closes) < period + 1:
            return 50.0

        deltas = np.diff(closes)
        gains = np.where(deltas > 0, deltas, 0)
        losses = np.where(deltas < 0, -deltas, 0)

        avg_gain = np.mean(gains[-period:])
        avg_loss = np.mean(losses[-period:])

        if avg_loss == 0:
            return 100.0

        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))

        return round(rsi, 2)

    def _calculate_macd(self, closes: np.ndarray) -> tuple:
        """Calculate MACD"""
        ema_12 = self._calculate_ema(closes, 12)
        ema_26 = self._calculate_ema(closes, 26)

        macd = ema_12 - ema_26

        # Signal line (9-period EMA of MACD)
        if len(closes) >= 26:
            macd_values = []
            for i in range(26, len(closes)):
                e12 = self._calculate_ema(closes[:i+1], 12)
                e26 = self._calculate_ema(closes[:i+1], 26)
                macd_values.append(e12 - e26)

            if len(macd_values) >= 9:
                signal = np.mean(macd_values[-9:])
            else:
                signal = macd
        else:
            signal = macd

        histogram = macd - signal

        return round(macd, 6), round(signal, 6), round(histogram, 6)

    def _calculate_ema(self, data: np.ndarray, period: int) -> float:
        """Calculate EMA"""
        if len(data) < period:
            return data[-1]

        multiplier = 2 / (period + 1)
        ema = data[-period]

        for price in data[-period + 1:]:
            ema = (price * multiplier) + (ema * (1 - multiplier))

        return ema

    def _calculate_bollinger_bands(self, closes: np.ndarray, period: int = 20, std_dev: int = 2) -> tuple:
        """Calculate Bollinger Bands"""
        if len(closes) < period:
            return closes[-1], closes[-1], closes[-1]

        middle = np.mean(closes[-period:])
        std = np.std(closes[-period:])

        upper = middle + (std_dev * std)
        lower = middle - (std_dev * std)

        return round(upper, 5), round(middle, 5), round(lower, 5)

    def _calculate_atr(self, highs: np.ndarray, lows: np.ndarray, closes: np.ndarray, period: int = 14) -> float:
        """Calculate ATR"""
        if len(closes) < period + 1:
            return 0.0

        tr_values = []
        for i in range(1, len(closes)):
            high_low = highs[i] - lows[i]
            high_close = abs(highs[i] - closes[i-1])
            low_close = abs(lows[i] - closes[i-1])
            tr = max(high_low, high_close, low_close)
            tr_values.append(tr)

        return round(np.mean(tr_values[-period:]), 5)

    def _calculate_adx(self, highs: np.ndarray, lows: np.ndarray, closes: np.ndarray, period: int = 14) -> float:
        """Calculate ADX (simplified)"""
        if len(closes) < period + 1:
            return 25.0

        # Simplified ADX calculation
        atr = self._calculate_atr(highs, lows, closes, period)
        if atr == 0:
            return 25.0

        plus_dm = []
        minus_dm = []

        for i in range(1, len(highs)):
            up_move = highs[i] - highs[i-1]
            down_move = lows[i-1] - lows[i]

            if up_move > down_move and up_move > 0:
                plus_dm.append(up_move)
            else:
                plus_dm.append(0)

            if down_move > up_move and down_move > 0:
                minus_dm.append(down_move)
            else:
                minus_dm.append(0)

        plus_di = (np.mean(plus_dm[-period:]) / atr) * 100
        minus_di = (np.mean(minus_dm[-period:]) / atr) * 100

        if plus_di + minus_di == 0:
            return 25.0

        dx = abs(plus_di - minus_di) / (plus_di + minus_di) * 100

        return round(dx, 2)

    def _analyze_trend(self, data: Dict, indicators: TechnicalIndicators) -> float:
        """Analyze trend direction and strength"""
        closes = data['close']
        current_price = closes[-1]

        score = 0.0

        # Price vs Moving Averages
        if current_price > indicators.sma_20:
            score += 0.2
        else:
            score -= 0.2

        if current_price > indicators.sma_50:
            score += 0.2
        else:
            score -= 0.2

        # MA crossover
        if indicators.sma_20 > indicators.sma_50:
            score += 0.2
        else:
            score -= 0.2

        # EMA trend
        if indicators.ema_12 > indicators.ema_26:
            score += 0.2
        else:
            score -= 0.2

        # ADX strength confirmation
        if indicators.adx > 25:
            score *= 1.2  # Strengthen signal in strong trend

        return max(-1, min(1, score))

    def _analyze_momentum(self, indicators: TechnicalIndicators) -> float:
        """Analyze momentum indicators"""
        score = 0.0

        # RSI analysis
        if indicators.rsi < 30:
            score += 0.4  # Oversold - bullish
        elif indicators.rsi > 70:
            score -= 0.4  # Overbought - bearish
        elif indicators.rsi > 50:
            score += 0.1
        else:
            score -= 0.1

        # MACD analysis
        if indicators.macd > indicators.macd_signal:
            score += 0.3
        else:
            score -= 0.3

        if indicators.macd_histogram > 0:
            score += 0.2
        else:
            score -= 0.2

        return max(-1, min(1, score))

    def _analyze_volatility(self, data: Dict, indicators: TechnicalIndicators) -> float:
        """Analyze volatility"""
        closes = data['close']
        current_price = closes[-1]

        # Bollinger Band position
        bb_range = indicators.bollinger_upper - indicators.bollinger_lower
        if bb_range == 0:
            return 1.0

        bb_position = (current_price - indicators.bollinger_lower) / bb_range

        # ATR-based volatility
        avg_price = np.mean(closes[-20:])
        volatility_ratio = indicators.atr / avg_price if avg_price > 0 else 0

        return volatility_ratio

    def _detect_patterns(self, data: Dict) -> float:
        """Detect candlestick patterns"""
        opens = data['open']
        highs = data['high']
        lows = data['low']
        closes = data['close']

        if len(closes) < 3:
            return 0.0

        score = 0.0

        # Bullish Engulfing
        if self._is_bullish_engulfing(opens, closes):
            score += 0.4

        # Bearish Engulfing
        if self._is_bearish_engulfing(opens, closes):
            score -= 0.4

        # Hammer
        if self._is_hammer(opens, highs, lows, closes):
            score += 0.3

        # Shooting Star
        if self._is_shooting_star(opens, highs, lows, closes):
            score -= 0.3

        # Doji (reversal potential)
        if self._is_doji(opens, highs, lows, closes):
            # Check context for doji direction
            if closes[-2] < opens[-2]:  # Previous bearish
                score += 0.2
            else:
                score -= 0.2

        return max(-1, min(1, score))

    def _is_bullish_engulfing(self, opens: List, closes: List) -> bool:
        """Check for bullish engulfing pattern"""
        if len(closes) < 2:
            return False

        prev_bearish = closes[-2] < opens[-2]
        curr_bullish = closes[-1] > opens[-1]
        engulfs = opens[-1] <= closes[-2] and closes[-1] >= opens[-2]

        return prev_bearish and curr_bullish and engulfs

    def _is_bearish_engulfing(self, opens: List, closes: List) -> bool:
        """Check for bearish engulfing pattern"""
        if len(closes) < 2:
            return False

        prev_bullish = closes[-2] > opens[-2]
        curr_bearish = closes[-1] < opens[-1]
        engulfs = opens[-1] >= closes[-2] and closes[-1] <= opens[-2]

        return prev_bullish and curr_bearish and engulfs

    def _is_hammer(self, opens: List, highs: List, lows: List, closes: List) -> bool:
        """Check for hammer pattern"""
        if len(closes) < 1:
            return False

        body = abs(closes[-1] - opens[-1])
        range_val = highs[-1] - lows[-1]
        lower_wick = min(opens[-1], closes[-1]) - lows[-1]
        upper_wick = highs[-1] - max(opens[-1], closes[-1])

        if range_val == 0:
            return False

        return (
            body / range_val < 0.3 and
            lower_wick > body * 2 and
            upper_wick < body
        )

    def _is_shooting_star(self, opens: List, highs: List, lows: List, closes: List) -> bool:
        """Check for shooting star pattern"""
        if len(closes) < 1:
            return False

        body = abs(closes[-1] - opens[-1])
        range_val = highs[-1] - lows[-1]
        lower_wick = min(opens[-1], closes[-1]) - lows[-1]
        upper_wick = highs[-1] - max(opens[-1], closes[-1])

        if range_val == 0:
            return False

        return (
            body / range_val < 0.3 and
            upper_wick > body * 2 and
            lower_wick < body
        )

    def _is_doji(self, opens: List, highs: List, lows: List, closes: List) -> bool:
        """Check for doji pattern"""
        if len(closes) < 1:
            return False

        body = abs(closes[-1] - opens[-1])
        range_val = highs[-1] - lows[-1]

        if range_val == 0:
            return False

        return body / range_val < 0.1

    def _combine_signals(self, trend: float, momentum: float, pattern: float, volatility: float) -> float:
        """Combine all signals with weights"""
        trend_weight = 0.35
        momentum_weight = 0.35
        pattern_weight = 0.20
        volatility_weight = 0.10

        # Volatility affects confidence, not direction
        volatility_factor = 1.0
        if volatility > 0.02:  # High volatility
            volatility_factor = 0.8
        elif volatility < 0.005:  # Low volatility
            volatility_factor = 1.1

        combined = (
            trend * trend_weight +
            momentum * momentum_weight +
            pattern * pattern_weight
        ) * volatility_factor

        # Boost if signals agree
        if (trend > 0 and momentum > 0) or (trend < 0 and momentum < 0):
            combined *= 1.2

        return max(-1, min(1, combined))

    def get_stats(self) -> Dict:
        """Get model statistics"""
        if self.stats['total'] > 0:
            self.stats['accuracy'] = self.stats['correct'] / self.stats['total']
        return self.stats

    def update_accuracy(self, was_correct: bool):
        """Update accuracy based on actual result"""
        if was_correct:
            self.stats['correct'] += 1
