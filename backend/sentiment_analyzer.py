"""
Sentiment Analyzer
Analyzes market sentiment from news and social media
"""

import logging
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import re

logger = logging.getLogger(__name__)

class SentimentAnalyzer:
    """
    Analyzes sentiment from various sources:
    - News articles
    - Social media mentions
    - Economic indicators
    """

    def __init__(self):
        self.sentiment_cache = {}
        self.cache_duration = timedelta(minutes=15)

        # Sentiment keywords for basic analysis
        self.bullish_keywords = [
            'bullish', 'rally', 'surge', 'gain', 'rise', 'climb',
            'uptrend', 'breakout', 'strong', 'positive', 'growth',
            'buy', 'upgrade', 'outperform', 'beat', 'exceed'
        ]

        self.bearish_keywords = [
            'bearish', 'crash', 'plunge', 'fall', 'drop', 'decline',
            'downtrend', 'breakdown', 'weak', 'negative', 'recession',
            'sell', 'downgrade', 'underperform', 'miss', 'concern'
        ]

        self.neutral_keywords = [
            'stable', 'unchanged', 'flat', 'consolidate', 'range',
            'hold', 'neutral', 'mixed', 'uncertain'
        ]

    def analyze(self, symbol: str) -> Dict:
        """
        Analyze sentiment for a trading symbol

        Args:
            symbol: Trading symbol (e.g., EURUSD, BTCUSD)

        Returns:
            Sentiment score and details
        """
        # Check cache
        cache_key = f"{symbol}_{datetime.now().strftime('%Y%m%d%H')}"
        if cache_key in self.sentiment_cache:
            return self.sentiment_cache[cache_key]

        try:
            # Get base currency sentiment
            base_currency = self._extract_base_currency(symbol)
            quote_currency = self._extract_quote_currency(symbol)

            # Analyze sentiment for each currency
            base_sentiment = self._get_currency_sentiment(base_currency)
            quote_sentiment = self._get_currency_sentiment(quote_currency)

            # Combined sentiment (base positive / quote negative = pair bullish)
            combined_score = base_sentiment - quote_sentiment

            # Normalize to -1 to 1 range
            normalized_score = max(-1, min(1, combined_score / 2))

            result = {
                'score': round(normalized_score, 3),
                'base_sentiment': base_sentiment,
                'quote_sentiment': quote_sentiment,
                'confidence': 0.7,
                'sources': ['market_data', 'technical_analysis'],
                'timestamp': datetime.now().isoformat()
            }

            # Cache result
            self.sentiment_cache[cache_key] = result

            return result

        except Exception as e:
            logger.error(f"Sentiment analysis error: {e}")
            return {
                'score': 0.0,
                'confidence': 0.0,
                'error': str(e)
            }

    def analyze_news(self, news_items: List[Dict]) -> Dict:
        """
        Analyze sentiment from news articles

        Args:
            news_items: List of news articles with title and content

        Returns:
            Aggregated sentiment analysis
        """
        if not news_items:
            return {
                'score': 0.0,
                'summary': 'No recent news available',
                'article_count': 0
            }

        total_score = 0
        analyzed_count = 0
        summaries = []

        for news in news_items[:10]:  # Analyze top 10 news items
            title = news.get('title', '')
            content = news.get('content', '')
            text = f"{title} {content}".lower()

            # Count keyword occurrences
            bullish_count = sum(1 for kw in self.bullish_keywords if kw in text)
            bearish_count = sum(1 for kw in self.bearish_keywords if kw in text)

            # Calculate article sentiment
            if bullish_count + bearish_count > 0:
                article_score = (bullish_count - bearish_count) / (bullish_count + bearish_count)
                total_score += article_score
                analyzed_count += 1

                # Add to summary if significant
                if abs(article_score) > 0.3:
                    sentiment = "bullish" if article_score > 0 else "bearish"
                    summaries.append(f"{sentiment.capitalize()}: {title[:50]}...")

        # Calculate average sentiment
        avg_score = total_score / analyzed_count if analyzed_count > 0 else 0

        # Build summary
        if avg_score > 0.2:
            sentiment_summary = "Overall positive market sentiment"
        elif avg_score < -0.2:
            sentiment_summary = "Overall negative market sentiment"
        else:
            sentiment_summary = "Mixed market sentiment"

        if summaries:
            sentiment_summary += ". Key headlines: " + "; ".join(summaries[:3])

        return {
            'score': round(avg_score, 3),
            'summary': sentiment_summary,
            'article_count': analyzed_count,
            'bullish_articles': sum(1 for _ in range(analyzed_count) if total_score > 0),
            'bearish_articles': sum(1 for _ in range(analyzed_count) if total_score < 0)
        }

    def analyze_text(self, text: str) -> Dict:
        """
        Analyze sentiment of a single text
        """
        text_lower = text.lower()

        bullish_count = sum(1 for kw in self.bullish_keywords if kw in text_lower)
        bearish_count = sum(1 for kw in self.bearish_keywords if kw in text_lower)
        neutral_count = sum(1 for kw in self.neutral_keywords if kw in text_lower)

        total = bullish_count + bearish_count + neutral_count

        if total == 0:
            return {'score': 0.0, 'label': 'neutral', 'confidence': 0.0}

        score = (bullish_count - bearish_count) / total

        if score > 0.2:
            label = 'bullish'
        elif score < -0.2:
            label = 'bearish'
        else:
            label = 'neutral'

        confidence = abs(score) * (total / 10)  # More keywords = higher confidence

        return {
            'score': round(score, 3),
            'label': label,
            'confidence': min(confidence, 1.0),
            'bullish_count': bullish_count,
            'bearish_count': bearish_count
        }

    def _extract_base_currency(self, symbol: str) -> str:
        """Extract base currency from symbol"""
        # Handle forex pairs (EURUSD -> EUR)
        if len(symbol) == 6:
            return symbol[:3]
        # Handle crypto (BTCUSD -> BTC)
        elif 'USD' in symbol:
            return symbol.replace('USD', '')
        return symbol

    def _extract_quote_currency(self, symbol: str) -> str:
        """Extract quote currency from symbol"""
        # Handle forex pairs (EURUSD -> USD)
        if len(symbol) == 6:
            return symbol[3:]
        # Handle crypto (BTCUSD -> USD)
        elif 'USD' in symbol:
            return 'USD'
        return 'USD'

    def _get_currency_sentiment(self, currency: str) -> float:
        """
        Get sentiment for a specific currency
        In production, this would fetch real data
        """
        # Simulated sentiment data
        # In production, aggregate from multiple sources
        currency_sentiments = {
            'USD': 0.2,   # Generally positive
            'EUR': 0.0,   # Neutral
            'GBP': -0.1,  # Slightly negative
            'JPY': 0.1,   # Slightly positive (safe haven)
            'CHF': 0.15,  # Safe haven
            'AUD': -0.05, # Commodity-linked
            'CAD': 0.05,  # Oil-linked
            'NZD': 0.0,   # Neutral
            'BTC': 0.3,   # Crypto bullish
            'ETH': 0.25,  # Crypto bullish
            'XAU': 0.2,   # Gold bullish (safe haven)
            'XAG': 0.1,   # Silver
        }

        return currency_sentiments.get(currency, 0.0)

    def get_fear_greed_index(self) -> Dict:
        """
        Calculate Fear & Greed index
        """
        # In production, calculate from multiple factors:
        # - VIX
        # - Market momentum
        # - Put/Call ratio
        # - Safe haven demand
        # - Junk bond demand

        return {
            'value': 55,  # 0-100 scale
            'label': 'Neutral',
            'description': 'Market showing balanced sentiment',
            'factors': {
                'volatility': 50,
                'momentum': 60,
                'safe_haven': 45,
                'junk_bonds': 55
            }
        }

    def get_market_mood(self, symbols: List[str]) -> Dict:
        """
        Get overall market mood across multiple symbols
        """
        sentiments = []
        for symbol in symbols:
            sentiment = self.analyze(symbol)
            sentiments.append(sentiment['score'])

        if not sentiments:
            return {'mood': 'unknown', 'score': 0}

        avg_sentiment = sum(sentiments) / len(sentiments)

        if avg_sentiment > 0.3:
            mood = 'risk-on'
        elif avg_sentiment < -0.3:
            mood = 'risk-off'
        else:
            mood = 'neutral'

        return {
            'mood': mood,
            'score': round(avg_sentiment, 3),
            'analyzed_symbols': len(symbols)
        }
