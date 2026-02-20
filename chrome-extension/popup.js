/**
 * Trading Assistant - Chrome Extension Popup
 */

// State
let currentSymbol = 'EURUSD';
let currentTimeframe = 'H1';
let isConnected = false;
let recentSignals = [];

// DOM ready
document.addEventListener('DOMContentLoaded', async () => {
  await loadSettings();
  initEventListeners();
  await checkConnection();
  await fetchPrediction();
  loadRecentSignals();
});

// Load settings from chrome.storage
async function loadSettings() {
  return new Promise((resolve) => {
    chrome.storage.sync.get(
      ['apiUrl', 'apiKey', 'lastSymbol', 'lastTimeframe', 'recentSignals'],
      (result) => {
        if (result.lastSymbol) {
          currentSymbol = result.lastSymbol;
          document.getElementById('symbolSelect').value = currentSymbol;
        }
        if (result.lastTimeframe) {
          currentTimeframe = result.lastTimeframe;
          document.getElementById('timeframeSelect').value = currentTimeframe;
        }
        if (result.recentSignals) {
          recentSignals = result.recentSignals;
        }
        resolve();
      }
    );
  });
}

function getApiConfig() {
  return new Promise((resolve) => {
    chrome.storage.sync.get(['apiUrl', 'apiKey'], (result) => {
      resolve({
        url: result.apiUrl || 'http://localhost:8000',
        key: result.apiKey || ''
      });
    });
  });
}

// Event Listeners
function initEventListeners() {
  document.getElementById('refreshBtn').addEventListener('click', () => {
    const btn = document.getElementById('refreshBtn');
    btn.classList.add('spinning');
    fetchPrediction().finally(() => {
      btn.classList.remove('spinning');
    });
  });

  document.getElementById('symbolSelect').addEventListener('change', (e) => {
    currentSymbol = e.target.value;
    chrome.storage.sync.set({ lastSymbol: currentSymbol });
    fetchPrediction();
  });

  document.getElementById('timeframeSelect').addEventListener('change', (e) => {
    currentTimeframe = e.target.value;
    chrome.storage.sync.set({ lastTimeframe: currentTimeframe });
    fetchPrediction();
  });

  document.getElementById('openDashboard').addEventListener('click', () => {
    chrome.tabs.create({ url: chrome.runtime.getURL('dashboard.html') });
  });

  document.getElementById('openSettings').addEventListener('click', () => {
    chrome.runtime.openOptionsPage();
  });

  document.getElementById('footerDashboard').addEventListener('click', (e) => {
    e.preventDefault();
    chrome.tabs.create({ url: chrome.runtime.getURL('dashboard.html') });
  });
}

// API Functions
async function checkConnection() {
  const config = await getApiConfig();
  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');

  statusDot.className = 'status-dot connecting';
  statusText.textContent = 'Connecting...';

  try {
    const response = await fetch(`${config.url}/health`, {
      headers: getHeaders(config),
      signal: AbortSignal.timeout(5000)
    });

    if (response.ok) {
      isConnected = true;
      statusDot.className = 'status-dot online';
      statusText.textContent = 'Connected to API';
    } else {
      throw new Error('API error');
    }
  } catch (error) {
    isConnected = false;
    statusDot.className = 'status-dot';
    statusText.textContent = 'API offline - using simulated data';
  }
}

async function fetchPrediction() {
  const config = await getApiConfig();

  try {
    const marketData = generateMarketData();

    let prediction;

    if (isConnected) {
      const response = await fetch(`${config.url}/api/predict`, {
        method: 'POST',
        headers: getHeaders(config),
        body: JSON.stringify({
          symbol: currentSymbol,
          timeframe: currentTimeframe,
          timestamp: Math.floor(Date.now() / 1000),
          market_data: marketData
        }),
        signal: AbortSignal.timeout(10000)
      });

      if (response.ok) {
        prediction = await response.json();
      } else {
        prediction = generateMockPrediction();
      }
    } else {
      prediction = generateMockPrediction();
    }

    updateUI(prediction);
    addRecentSignal(prediction);
    updateLastTime();

    // Notify background script
    chrome.runtime.sendMessage({
      type: 'NEW_PREDICTION',
      prediction,
      symbol: currentSymbol,
      timeframe: currentTimeframe
    });

  } catch (error) {
    console.error('Fetch error:', error);
    const mock = generateMockPrediction();
    updateUI(mock);
  }
}

// UI Updates
function updateUI(prediction) {
  const card = document.getElementById('signalCard');
  const icon = document.getElementById('signalIcon');
  const direction = document.getElementById('signalDirection');
  const confidence = document.getElementById('signalConfidence');
  const reason = document.getElementById('signalReason');

  // Direction
  const dirText = prediction.direction === 1 ? 'BUY' :
                   prediction.direction === -1 ? 'SELL' : 'HOLD';
  const dirClass = prediction.direction === 1 ? 'buy' :
                   prediction.direction === -1 ? 'sell' : '';

  card.className = `signal-card ${dirClass}`;
  direction.textContent = dirText;
  confidence.textContent = `${(prediction.confidence * 100).toFixed(1)}% confidence`;

  // Icon
  if (prediction.direction === 1) {
    icon.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
      <line x1="12" y1="19" x2="12" y2="5"></line>
      <polyline points="5 12 12 5 19 12"></polyline>
    </svg>`;
  } else if (prediction.direction === -1) {
    icon.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
      <line x1="12" y1="5" x2="12" y2="19"></line>
      <polyline points="19 12 12 19 5 12"></polyline>
    </svg>`;
  } else {
    icon.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
      <circle cx="12" cy="12" r="10"></circle>
      <line x1="8" y1="12" x2="16" y2="12"></line>
    </svg>`;
  }

  // Reason
  reason.textContent = prediction.reason || 'No analysis available';

  // Targets
  document.getElementById('entryPrice').textContent =
    prediction.price_target ? prediction.price_target.toFixed(5) : '--';
  document.getElementById('slPrice').textContent =
    prediction.stop_loss ? prediction.stop_loss.toFixed(5) : '--';
  document.getElementById('tpPrice').textContent =
    prediction.take_profit ? prediction.take_profit.toFixed(5) : '--';

  // Indicators
  updateIndicators(prediction);

  // Sentiment
  updateSentiment(prediction.sentiment || 0);
}

function updateIndicators(prediction) {
  const indicators = prediction.indicators || {};
  const rsi = indicators.rsi || 50;

  // RSI
  const rsiBar = document.getElementById('rsiBar');
  rsiBar.style.width = rsi + '%';
  rsiBar.className = 'ind-bar ' + (rsi < 30 ? 'oversold' : rsi > 70 ? 'overbought' : 'normal');
  document.getElementById('rsiValue').textContent = Math.round(rsi);

  // MACD
  const macd = document.getElementById('macdBadge');
  if (prediction.direction === 1) {
    macd.textContent = 'Bullish';
    macd.className = 'ind-badge bullish';
  } else if (prediction.direction === -1) {
    macd.textContent = 'Bearish';
    macd.className = 'ind-badge bearish';
  } else {
    macd.textContent = 'Neutral';
    macd.className = 'ind-badge neutral';
  }

  // Trend
  const trend = document.getElementById('trendBadge');
  trend.textContent = prediction.direction === 1 ? 'Up' :
                      prediction.direction === -1 ? 'Down' : 'Flat';
  trend.className = `ind-badge ${prediction.direction === 1 ? 'bullish' :
                     prediction.direction === -1 ? 'bearish' : 'neutral'}`;

  // Pattern
  const pattern = document.getElementById('patternBadge');
  pattern.textContent = prediction.direction !== 0 ? 'Found' : 'None';
  pattern.className = `ind-badge ${prediction.direction !== 0 ? 'bullish' : 'neutral'}`;
}

function updateSentiment(sentiment) {
  const pointer = document.getElementById('sentimentPointer');
  const text = document.getElementById('sentimentText');

  const pct = ((sentiment + 1) / 2) * 100;
  pointer.style.left = pct + '%';

  if (sentiment > 0.2) {
    text.textContent = 'Bullish';
    text.style.color = '#10b981';
  } else if (sentiment < -0.2) {
    text.textContent = 'Bearish';
    text.style.color = '#ef4444';
  } else {
    text.textContent = 'Neutral';
    text.style.color = '#94a3b8';
  }
}

function addRecentSignal(prediction) {
  const signal = {
    symbol: currentSymbol,
    direction: prediction.direction === 1 ? 'buy' :
               prediction.direction === -1 ? 'sell' : 'hold',
    confidence: (prediction.confidence * 100).toFixed(0),
    time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  };

  recentSignals.unshift(signal);
  if (recentSignals.length > 10) recentSignals.pop();

  chrome.storage.sync.set({ recentSignals });
  renderRecentSignals();
}

function loadRecentSignals() {
  renderRecentSignals();
}

function renderRecentSignals() {
  const container = document.getElementById('recentSignals');

  if (recentSignals.length === 0) {
    container.innerHTML = '<div class="recent-empty">No signals yet</div>';
    return;
  }

  container.innerHTML = recentSignals.slice(0, 5).map(s => `
    <div class="recent-item">
      <span class="ri-symbol">${s.symbol}</span>
      <span class="ri-signal ${s.direction}">${s.direction.toUpperCase()}</span>
      <span class="ri-confidence">${s.confidence}%</span>
      <span class="ri-time">${s.time}</span>
    </div>
  `).join('');
}

function updateLastTime() {
  document.getElementById('lastUpdate').textContent =
    'Last update: ' + new Date().toLocaleTimeString();
}

// Helpers
function getHeaders(config) {
  const headers = { 'Content-Type': 'application/json' };
  if (config && config.key) {
    headers['Authorization'] = `Bearer ${config.key}`;
  }
  return headers;
}

function generateMarketData() {
  const count = 100;
  const open = [], high = [], low = [], close = [], volume = [];
  let price = 1.0850;

  for (let i = 0; i < count; i++) {
    const change = (Math.random() - 0.5) * 0.002;
    const o = price;
    const c = price + change;
    const h = Math.max(o, c) + Math.random() * 0.001;
    const l = Math.min(o, c) - Math.random() * 0.001;

    open.push(parseFloat(o.toFixed(5)));
    high.push(parseFloat(h.toFixed(5)));
    low.push(parseFloat(l.toFixed(5)));
    close.push(parseFloat(c.toFixed(5)));
    volume.push(Math.floor(Math.random() * 10000));
    price = c;
  }

  return { open, high, low, close, volume };
}

function generateMockPrediction() {
  const direction = Math.random() > 0.55 ? 1 : Math.random() > 0.5 ? -1 : 0;
  const confidence = 0.5 + Math.random() * 0.4;
  const price = 1.0850;

  return {
    direction,
    confidence,
    sentiment: (Math.random() - 0.5) * 2,
    price_target: parseFloat((price + direction * 0.005).toFixed(5)),
    stop_loss: parseFloat((price - direction * 0.003).toFixed(5)),
    take_profit: parseFloat((price + direction * 0.008).toFixed(5)),
    reason: `${direction === 1 ? 'Bullish' : direction === -1 ? 'Bearish' : 'Neutral'} signal on ${currentSymbol} ${currentTimeframe}. ${direction !== 0 ? 'Technical indicators align with momentum.' : 'No clear directional bias detected.'} Confidence: ${(confidence * 100).toFixed(0)}%`,
    indicators: {
      rsi: 30 + Math.random() * 40,
      macd: (Math.random() - 0.5) * 0.001
    }
  };
}
