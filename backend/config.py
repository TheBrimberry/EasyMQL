"""
Trading Assistant Configuration
Environment and application settings
"""

import os
from dataclasses import dataclass
from typing import Optional

@dataclass
class Config:
    """Application configuration"""

    # API Settings
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    API_DEBUG: bool = True

    # LLM Settings
    LLM_PROVIDER: str = "local"  # Options: 'openai', 'anthropic', 'local', 'huggingface'
    OPENAI_API_KEY: Optional[str] = None
    ANTHROPIC_API_KEY: Optional[str] = None
    HUGGINGFACE_API_KEY: Optional[str] = None
    LOCAL_MODEL_PATH: Optional[str] = None

    # Model Settings
    MODEL_NAME: str = "llama-finbot"
    MAX_TOKENS: int = 1024
    TEMPERATURE: float = 0.7

    # Trading Settings
    DEFAULT_RISK_PERCENT: float = 1.0
    MAX_POSITIONS: int = 5
    MIN_CONFIDENCE: float = 0.7

    # Cache Settings
    CACHE_DURATION_MINUTES: int = 5
    NEWS_CACHE_MINUTES: int = 15

    # Data Sources
    NEWS_SOURCES: list = None
    SENTIMENT_SOURCES: list = None

    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FILE: Optional[str] = None

    def __post_init__(self):
        # Load from environment variables
        self.OPENAI_API_KEY = os.getenv('OPENAI_API_KEY', self.OPENAI_API_KEY)
        self.ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY', self.ANTHROPIC_API_KEY)
        self.HUGGINGFACE_API_KEY = os.getenv('HUGGINGFACE_API_KEY', self.HUGGINGFACE_API_KEY)

        self.API_HOST = os.getenv('API_HOST', self.API_HOST)
        self.API_PORT = int(os.getenv('API_PORT', self.API_PORT))
        self.API_DEBUG = os.getenv('API_DEBUG', str(self.API_DEBUG)).lower() == 'true'

        self.LLM_PROVIDER = os.getenv('LLM_PROVIDER', self.LLM_PROVIDER)
        self.LOCAL_MODEL_PATH = os.getenv('LOCAL_MODEL_PATH', self.LOCAL_MODEL_PATH)

        if self.NEWS_SOURCES is None:
            self.NEWS_SOURCES = ['reuters', 'bloomberg', 'forex_factory']

        if self.SENTIMENT_SOURCES is None:
            self.SENTIMENT_SOURCES = ['news', 'social', 'market_data']

# Global config instance
config = Config()

# Supported trading symbols
SUPPORTED_SYMBOLS = {
    'forex': [
        'EURUSD', 'GBPUSD', 'USDJPY', 'USDCHF', 'AUDUSD',
        'USDCAD', 'NZDUSD', 'EURJPY', 'GBPJPY', 'EURGBP',
        'AUDJPY', 'EURAUD', 'EURCHF', 'AUDNZD', 'NZDJPY'
    ],
    'indices': [
        'US30', 'US500', 'US100', 'GER40', 'UK100', 'JP225',
        'AUS200', 'FRA40', 'ESP35'
    ],
    'commodities': [
        'XAUUSD', 'XAGUSD', 'USOIL', 'UKOIL', 'XPTUSD', 'XPDUSD'
    ],
    'crypto': [
        'BTCUSD', 'ETHUSD', 'LTCUSD', 'XRPUSD', 'ADAUSD', 'DOTUSD'
    ]
}

# Timeframe mappings
TIMEFRAMES = {
    'M1': 1,
    'M5': 5,
    'M15': 15,
    'M30': 30,
    'H1': 60,
    'H4': 240,
    'D1': 1440,
    'W1': 10080,
    'MN1': 43200
}

# Technical indicator defaults
INDICATOR_DEFAULTS = {
    'rsi_period': 14,
    'rsi_overbought': 70,
    'rsi_oversold': 30,
    'macd_fast': 12,
    'macd_slow': 26,
    'macd_signal': 9,
    'bb_period': 20,
    'bb_std': 2,
    'atr_period': 14,
    'adx_period': 14,
    'ma_fast': 20,
    'ma_slow': 50
}

# Signal thresholds
SIGNAL_THRESHOLDS = {
    'strong_buy': 0.7,
    'buy': 0.3,
    'hold_upper': 0.3,
    'hold_lower': -0.3,
    'sell': -0.3,
    'strong_sell': -0.7
}
