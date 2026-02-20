/**
 * Trading Assistant - Options Page
 */

const DEFAULT_CONFIG = {
  apiUrl: 'http://localhost:8000',
  apiKey: '',
  autoRefreshMinutes: 1,
  notificationsEnabled: true,
  soundEnabled: true,
  badgeEnabled: true,
  minConfidence: 70,
  watchlist: ['EURUSD', 'GBPUSD', 'USDJPY', 'BTCUSD', 'XAUUSD']
};

let watchlist = [...DEFAULT_CONFIG.watchlist];

document.addEventListener('DOMContentLoaded', () => {
  loadSettings();
  initEventListeners();
});

function loadSettings() {
  chrome.storage.sync.get(null, (result) => {
    const config = { ...DEFAULT_CONFIG, ...result };

    document.getElementById('apiUrl').value = config.apiUrl;
    document.getElementById('apiKey').value = config.apiKey;
    document.getElementById('minConfidence').value = config.minConfidence;
    document.getElementById('confidenceValue').textContent = config.minConfidence + '%';
    document.getElementById('autoRefresh').value = config.autoRefreshMinutes;
    document.getElementById('notificationsEnabled').checked = config.notificationsEnabled;
    document.getElementById('soundEnabled').checked = config.soundEnabled;
    document.getElementById('badgeEnabled').checked = config.badgeEnabled !== false;

    watchlist = config.watchlist || DEFAULT_CONFIG.watchlist;
    renderWatchlist();
  });
}

function initEventListeners() {
  // Confidence slider
  document.getElementById('minConfidence').addEventListener('input', (e) => {
    document.getElementById('confidenceValue').textContent = e.target.value + '%';
  });

  // Save
  document.getElementById('saveBtn').addEventListener('click', saveSettings);

  // Reset
  document.getElementById('resetBtn').addEventListener('click', () => {
    if (confirm('Reset all settings to defaults?')) {
      chrome.storage.sync.set(DEFAULT_CONFIG, () => {
        loadSettings();
        showToast('Settings reset to defaults', 'success');
      });
    }
  });

  // Test connection
  document.getElementById('testConnectionBtn').addEventListener('click', testConnection);

  // Add symbol
  document.getElementById('addSymbolBtn').addEventListener('click', addSymbol);
  document.getElementById('addSymbolInput').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') addSymbol();
  });
}

function saveSettings() {
  const config = {
    apiUrl: document.getElementById('apiUrl').value.replace(/\/$/, ''),
    apiKey: document.getElementById('apiKey').value,
    minConfidence: parseInt(document.getElementById('minConfidence').value),
    autoRefreshMinutes: parseInt(document.getElementById('autoRefresh').value),
    notificationsEnabled: document.getElementById('notificationsEnabled').checked,
    soundEnabled: document.getElementById('soundEnabled').checked,
    badgeEnabled: document.getElementById('badgeEnabled').checked,
    watchlist: watchlist
  };

  chrome.storage.sync.set(config, () => {
    showToast('Settings saved successfully', 'success');

    // Notify background script to update alarms
    chrome.runtime.sendMessage({ type: 'UPDATE_SETTINGS' });
  });
}

async function testConnection() {
  const url = document.getElementById('apiUrl').value.replace(/\/$/, '');
  const dot = document.getElementById('connDot');
  const text = document.getElementById('connText');

  dot.className = 'dot';
  dot.style.background = '#f59e0b';
  text.textContent = 'Testing...';

  try {
    const response = await fetch(`${url}/health`, {
      signal: AbortSignal.timeout(5000)
    });

    if (response.ok) {
      const data = await response.json();
      dot.className = 'dot online';
      text.textContent = `Connected - v${data.version || '1.0.0'}`;
      showToast('Connection successful', 'success');
    } else {
      throw new Error(`HTTP ${response.status}`);
    }
  } catch (error) {
    dot.className = 'dot offline';
    text.textContent = `Connection failed: ${error.message}`;
    showToast('Connection failed', 'error');
  }
}

function addSymbol() {
  const input = document.getElementById('addSymbolInput');
  const symbol = input.value.trim().toUpperCase();

  if (!symbol) return;
  if (symbol.length < 3 || symbol.length > 10) {
    showToast('Symbol must be 3-10 characters', 'error');
    return;
  }
  if (watchlist.includes(symbol)) {
    showToast('Symbol already in watchlist', 'error');
    return;
  }

  watchlist.push(symbol);
  renderWatchlist();
  input.value = '';
}

function removeSymbol(symbol) {
  watchlist = watchlist.filter(s => s !== symbol);
  renderWatchlist();
}

function renderWatchlist() {
  const container = document.getElementById('watchlistContainer');
  container.innerHTML = watchlist.map(symbol => `
    <div class="watchlist-tag">
      <span>${symbol}</span>
      <button class="remove-btn" onclick="removeSymbol('${symbol}')">&times;</button>
    </div>
  `).join('');
}

function showToast(message, type = 'success') {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.className = `toast ${type} visible`;

  setTimeout(() => {
    toast.className = 'toast';
  }, 3000);
}
