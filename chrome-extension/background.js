/**
 * Trading Assistant - Background Service Worker
 * Handles alarms, notifications, and persistent state
 */

// Default settings
const DEFAULT_CONFIG = {
  apiUrl: 'http://localhost:8000',
  apiKey: '',
  autoRefreshMinutes: 1,
  notificationsEnabled: true,
  soundEnabled: true,
  minConfidence: 70,
  watchlist: ['EURUSD', 'GBPUSD', 'USDJPY', 'BTCUSD', 'XAUUSD']
};

// Initialize on install
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    chrome.storage.sync.set(DEFAULT_CONFIG);
    console.log('Trading Assistant installed with default settings');
  }

  // Set up alarms for periodic prediction fetching
  setupAlarms();
});

// Set up periodic alarms
async function setupAlarms() {
  const config = await getConfig();
  const intervalMinutes = config.autoRefreshMinutes || 1;

  // Clear existing alarms
  await chrome.alarms.clearAll();

  // Create refresh alarm
  chrome.alarms.create('fetchPredictions', {
    periodInMinutes: Math.max(intervalMinutes, 1)
  });

  // Create health check alarm (every 5 minutes)
  chrome.alarms.create('healthCheck', {
    periodInMinutes: 5
  });

  console.log(`Alarms set: predictions every ${intervalMinutes}m, health every 5m`);
}

// Handle alarms
chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'fetchPredictions') {
    await fetchWatchlistPredictions();
  } else if (alarm.name === 'healthCheck') {
    await checkApiHealth();
  }
});

// Listen for messages from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  switch (message.type) {
    case 'NEW_PREDICTION':
      handleNewPrediction(message);
      break;
    case 'UPDATE_SETTINGS':
      setupAlarms();
      break;
    case 'GET_STATUS':
      getStatus().then(sendResponse);
      return true; // async response
    case 'FETCH_PREDICTION':
      fetchSinglePrediction(message.symbol, message.timeframe)
        .then(sendResponse);
      return true;
  }
});

// Fetch predictions for watchlist symbols
async function fetchWatchlistPredictions() {
  const config = await getConfig();
  const watchlist = config.watchlist || DEFAULT_CONFIG.watchlist;

  for (const symbol of watchlist) {
    try {
      const prediction = await fetchSinglePrediction(symbol, 'H1');

      if (prediction && prediction.confidence >= (config.minConfidence || 70) / 100) {
        if (prediction.direction !== 0 && config.notificationsEnabled) {
          showNotification(symbol, prediction);
        }
      }
    } catch (error) {
      console.error(`Error fetching prediction for ${symbol}:`, error);
    }
  }
}

// Fetch single prediction
async function fetchSinglePrediction(symbol, timeframe) {
  const config = await getConfig();

  try {
    const marketData = generateMarketData();

    const response = await fetch(`${config.apiUrl}/api/predict`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(config.apiKey ? { 'Authorization': `Bearer ${config.apiKey}` } : {})
      },
      body: JSON.stringify({
        symbol,
        timeframe,
        timestamp: Math.floor(Date.now() / 1000),
        market_data: marketData
      })
    });

    if (response.ok) {
      const prediction = await response.json();
      await savePrediction(symbol, prediction);
      return prediction;
    }
  } catch (error) {
    console.error('Prediction fetch error:', error);
  }

  return null;
}

// Handle new prediction from popup
async function handleNewPrediction(message) {
  const { prediction, symbol } = message;
  const config = await getConfig();

  // Save to history
  await savePrediction(symbol, prediction);

  // Check for notification-worthy signals
  if (
    prediction.direction !== 0 &&
    prediction.confidence >= (config.minConfidence || 70) / 100 &&
    config.notificationsEnabled
  ) {
    showNotification(symbol, prediction);
  }

  // Update badge
  updateBadge(prediction);
}

// Show notification
function showNotification(symbol, prediction) {
  const direction = prediction.direction === 1 ? 'BUY' : 'SELL';
  const confidence = (prediction.confidence * 100).toFixed(0);

  chrome.notifications.create(`signal-${symbol}-${Date.now()}`, {
    type: 'basic',
    iconUrl: 'icons/icon128.png',
    title: `${direction} Signal - ${symbol}`,
    message: `${direction} signal with ${confidence}% confidence.\n${prediction.reason || ''}`,
    priority: 2,
    requireInteraction: false
  });
}

// Update extension badge
function updateBadge(prediction) {
  if (prediction.direction === 1) {
    chrome.action.setBadgeText({ text: 'BUY' });
    chrome.action.setBadgeBackgroundColor({ color: '#10b981' });
  } else if (prediction.direction === -1) {
    chrome.action.setBadgeText({ text: 'SELL' });
    chrome.action.setBadgeBackgroundColor({ color: '#ef4444' });
  } else {
    chrome.action.setBadgeText({ text: '' });
  }

  // Clear badge after 30 seconds
  setTimeout(() => {
    chrome.action.setBadgeText({ text: '' });
  }, 30000);
}

// Check API health
async function checkApiHealth() {
  const config = await getConfig();

  try {
    const response = await fetch(`${config.apiUrl}/health`, {
      signal: AbortSignal.timeout(5000)
    });

    const healthy = response.ok;

    await chrome.storage.local.set({
      apiHealthy: healthy,
      lastHealthCheck: Date.now()
    });

    return healthy;
  } catch (error) {
    await chrome.storage.local.set({
      apiHealthy: false,
      lastHealthCheck: Date.now()
    });
    return false;
  }
}

// Save prediction to history
async function savePrediction(symbol, prediction) {
  const key = 'predictionHistory';
  const result = await chrome.storage.local.get(key);
  const history = result[key] || [];

  history.unshift({
    symbol,
    prediction,
    timestamp: Date.now()
  });

  // Keep last 100 predictions
  if (history.length > 100) {
    history.length = 100;
  }

  await chrome.storage.local.set({ [key]: history });
}

// Get current status
async function getStatus() {
  const healthResult = await chrome.storage.local.get(['apiHealthy', 'lastHealthCheck']);
  const historyResult = await chrome.storage.local.get('predictionHistory');

  return {
    apiHealthy: healthResult.apiHealthy || false,
    lastHealthCheck: healthResult.lastHealthCheck || 0,
    totalPredictions: (historyResult.predictionHistory || []).length
  };
}

// Get configuration
function getConfig() {
  return new Promise((resolve) => {
    chrome.storage.sync.get(null, (result) => {
      resolve({ ...DEFAULT_CONFIG, ...result });
    });
  });
}

// Generate market data (for background fetches)
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

// Handle notification clicks
chrome.notifications.onClicked.addListener((notificationId) => {
  // Open popup when notification is clicked
  chrome.action.openPopup();
});
