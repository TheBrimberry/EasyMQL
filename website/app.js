/**
 * Trading Assistant Dashboard - JavaScript Application
 * AI-Powered Trading Signals with LLM Integration
 */

// Configuration
const CONFIG = {
    apiUrl: localStorage.getItem('apiUrl') || 'http://localhost:8000',
    apiKey: localStorage.getItem('apiKey') || '',
    autoRefresh: parseInt(localStorage.getItem('autoRefresh')) || 60,
    minConfidence: parseInt(localStorage.getItem('minConfidence')) || 70,
    soundAlerts: localStorage.getItem('soundAlerts') !== 'false',
    browserNotifications: localStorage.getItem('browserNotifications') === 'true'
};

// State
let state = {
    currentSymbol: 'EURUSD',
    currentTimeframe: 'H1',
    isConnected: false,
    lastPrediction: null,
    signalHistory: [],
    priceChart: null,
    sentimentGauge: null,
    refreshInterval: null
};

// DOM Elements
const elements = {
    apiStatus: document.getElementById('apiStatus'),
    symbolSelect: document.getElementById('symbolSelect'),
    timeframeSelect: document.getElementById('timeframeSelect'),
    refreshBtn: document.getElementById('refreshBtn'),
    loadingOverlay: document.getElementById('loadingOverlay'),
    toastContainer: document.getElementById('toastContainer'),
    menuToggle: document.getElementById('menuToggle'),
    sidebar: document.querySelector('.sidebar'),
    pageTitle: document.getElementById('pageTitle')
};

// Initialize Application
document.addEventListener('DOMContentLoaded', () => {
    initNavigation();
    initCharts();
    initEventListeners();
    loadSettings();
    testConnection();
    startAutoRefresh();
});

// Navigation
function initNavigation() {
    const navItems = document.querySelectorAll('.nav-item');
    const sections = document.querySelectorAll('.section');

    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();

            // Update active nav
            navItems.forEach(nav => nav.classList.remove('active'));
            item.classList.add('active');

            // Show section
            const sectionId = item.dataset.section + 'Section';
            sections.forEach(section => section.classList.remove('active'));
            document.getElementById(sectionId).classList.add('active');

            // Update title
            elements.pageTitle.textContent = item.querySelector('span').textContent;

            // Close mobile menu
            elements.sidebar.classList.remove('open');
        });
    });

    // Mobile menu toggle
    elements.menuToggle.addEventListener('click', () => {
        elements.sidebar.classList.toggle('open');
    });
}

// Charts Initialization
function initCharts() {
    // Price Chart
    const priceCtx = document.getElementById('priceChart').getContext('2d');
    state.priceChart = new Chart(priceCtx, {
        type: 'line',
        data: {
            labels: generateTimeLabels(50),
            datasets: [{
                label: 'Price',
                data: generateMockPriceData(50),
                borderColor: '#3b82f6',
                backgroundColor: 'rgba(59, 130, 246, 0.1)',
                fill: true,
                tension: 0.1,
                pointRadius: 0,
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                x: {
                    grid: {
                        color: '#334155'
                    },
                    ticks: {
                        color: '#94a3b8',
                        maxTicksLimit: 10
                    }
                },
                y: {
                    grid: {
                        color: '#334155'
                    },
                    ticks: {
                        color: '#94a3b8'
                    }
                }
            },
            interaction: {
                intersect: false,
                mode: 'index'
            }
        }
    });

    // Sentiment Gauge
    const sentimentCtx = document.getElementById('sentimentGauge').getContext('2d');
    state.sentimentGauge = new Chart(sentimentCtx, {
        type: 'doughnut',
        data: {
            labels: ['Bullish', 'Bearish'],
            datasets: [{
                data: [50, 50],
                backgroundColor: ['#10b981', '#ef4444'],
                borderWidth: 0
            }]
        },
        options: {
            responsive: true,
            cutout: '70%',
            plugins: {
                legend: {
                    display: false
                }
            }
        }
    });
}

// Event Listeners
function initEventListeners() {
    // Symbol change
    elements.symbolSelect.addEventListener('change', (e) => {
        state.currentSymbol = e.target.value;
        fetchPrediction();
    });

    // Timeframe change
    elements.timeframeSelect.addEventListener('change', (e) => {
        state.currentTimeframe = e.target.value;
        fetchPrediction();
    });

    // Refresh button
    elements.refreshBtn.addEventListener('click', () => {
        fetchPrediction();
    });

    // Settings
    document.getElementById('saveApiSettings').addEventListener('click', saveSettings);
    document.getElementById('testConnection').addEventListener('click', testConnection);

    document.getElementById('minConfidence').addEventListener('input', (e) => {
        document.getElementById('minConfidenceValue').textContent = e.target.value + '%';
        CONFIG.minConfidence = parseInt(e.target.value);
        localStorage.setItem('minConfidence', e.target.value);
    });

    document.getElementById('autoRefresh').addEventListener('change', (e) => {
        CONFIG.autoRefresh = parseInt(e.target.value);
        localStorage.setItem('autoRefresh', e.target.value);
        startAutoRefresh();
    });

    document.getElementById('soundAlerts').addEventListener('change', (e) => {
        CONFIG.soundAlerts = e.target.checked;
        localStorage.setItem('soundAlerts', e.target.checked);
    });

    document.getElementById('browserNotifications').addEventListener('change', (e) => {
        CONFIG.browserNotifications = e.target.checked;
        localStorage.setItem('browserNotifications', e.target.checked);
        if (e.target.checked) {
            requestNotificationPermission();
        }
    });

    // Generate Analysis
    document.getElementById('generateAnalysis').addEventListener('click', fetchAnalysis);

    // Refresh News
    document.getElementById('refreshNews').addEventListener('click', fetchNews);
}

// API Functions
async function testConnection() {
    try {
        showLoading();
        const response = await fetch(`${CONFIG.apiUrl}/health`, {
            headers: getHeaders()
        });

        if (response.ok) {
            const data = await response.json();
            updateConnectionStatus(true);
            showToast('Connected to API successfully', 'success');
            fetchPrediction();
        } else {
            throw new Error('API not responding');
        }
    } catch (error) {
        updateConnectionStatus(false);
        showToast('Failed to connect to API', 'error');
        console.error('Connection error:', error);
    } finally {
        hideLoading();
    }
}

async function fetchPrediction() {
    try {
        showLoading();

        // Generate mock market data for the request
        const marketData = generateMockMarketData();

        const response = await fetch(`${CONFIG.apiUrl}/api/predict`, {
            method: 'POST',
            headers: getHeaders(),
            body: JSON.stringify({
                symbol: state.currentSymbol,
                timeframe: state.currentTimeframe,
                timestamp: Math.floor(Date.now() / 1000),
                market_data: marketData
            })
        });

        if (response.ok) {
            const prediction = await response.json();
            updatePredictionDisplay(prediction);
            state.lastPrediction = prediction;
            addToSignalHistory(prediction);

            // Alert if high confidence signal
            if (prediction.confidence >= CONFIG.minConfidence / 100) {
                if (CONFIG.soundAlerts) {
                    playAlertSound();
                }
                if (CONFIG.browserNotifications) {
                    showNotification(prediction);
                }
            }
        } else {
            // Use mock prediction if API fails
            const mockPrediction = generateMockPrediction();
            updatePredictionDisplay(mockPrediction);
            showToast('Using simulated prediction (API unavailable)', 'warning');
        }
    } catch (error) {
        console.error('Prediction error:', error);
        // Use mock prediction
        const mockPrediction = generateMockPrediction();
        updatePredictionDisplay(mockPrediction);
    } finally {
        hideLoading();
    }
}

async function fetchAnalysis() {
    try {
        showLoading();

        const response = await fetch(`${CONFIG.apiUrl}/api/analysis/${state.currentSymbol}`, {
            headers: getHeaders()
        });

        if (response.ok) {
            const analysis = await response.json();
            updateAnalysisDisplay(analysis);
        } else {
            // Mock analysis
            updateAnalysisDisplay(generateMockAnalysis());
        }
    } catch (error) {
        console.error('Analysis error:', error);
        updateAnalysisDisplay(generateMockAnalysis());
    } finally {
        hideLoading();
    }
}

async function fetchNews() {
    try {
        const response = await fetch(`${CONFIG.apiUrl}/api/sentiment/${state.currentSymbol}`, {
            headers: getHeaders()
        });

        if (response.ok) {
            const sentiment = await response.json();
            updateNewsDisplay(sentiment);
        } else {
            updateNewsDisplay(generateMockNews());
        }
    } catch (error) {
        console.error('News error:', error);
        updateNewsDisplay(generateMockNews());
    }
}

// UI Update Functions
function updateConnectionStatus(connected) {
    state.isConnected = connected;
    const statusDot = elements.apiStatus.querySelector('.status-dot');
    statusDot.classList.toggle('online', connected);
    statusDot.classList.toggle('offline', !connected);
}

function updatePredictionDisplay(prediction) {
    // Update stats
    const signalText = prediction.direction === 1 ? 'BUY' :
                       prediction.direction === -1 ? 'SELL' : 'HOLD';
    const signalClass = prediction.direction === 1 ? 'bullish' :
                        prediction.direction === -1 ? 'bearish' : 'neutral';

    document.getElementById('currentSignal').textContent = signalText;
    document.getElementById('currentSignal').className = `stat-value ${signalClass}`;

    document.getElementById('confidence').textContent =
        (prediction.confidence * 100).toFixed(1) + '%';

    const sentimentValue = prediction.sentiment > 0 ? 'Bullish' :
                           prediction.sentiment < 0 ? 'Bearish' : 'Neutral';
    document.getElementById('sentiment').textContent = sentimentValue;

    // Update signal display
    const signalDisplay = document.getElementById('signalDisplay');
    signalDisplay.className = `signal-display ${signalClass}`;
    signalDisplay.querySelector('.signal-icon').innerHTML =
        prediction.direction === 1 ? '<i class="fas fa-arrow-up"></i>' :
        prediction.direction === -1 ? '<i class="fas fa-arrow-down"></i>' :
        '<i class="fas fa-minus"></i>';
    signalDisplay.querySelector('.signal-text').textContent =
        `${signalText} Signal - ${(prediction.confidence * 100).toFixed(1)}% Confidence`;

    // Update details
    document.getElementById('priceTarget').textContent = prediction.price_target?.toFixed(5) || '--';
    document.getElementById('stopLoss').textContent = prediction.stop_loss?.toFixed(5) || '--';
    document.getElementById('takeProfit').textContent = prediction.take_profit?.toFixed(5) || '--';

    // Update reason
    document.getElementById('signalReason').querySelector('p').textContent =
        prediction.reason || 'No analysis available';

    // Update time
    document.getElementById('predictionTime').textContent =
        new Date().toLocaleTimeString();

    // Update indicators
    updateIndicators(prediction);

    // Update sentiment gauge
    updateSentimentGauge(prediction.sentiment);

    // Update chart
    updatePriceChart();
}

function updateIndicators(prediction) {
    const indicators = prediction.indicators || {};

    // RSI
    const rsi = indicators.rsi || 50;
    document.getElementById('rsiBar').style.width = rsi + '%';
    document.getElementById('rsiValue').textContent = rsi.toFixed(0);

    // MACD
    const macdSignal = document.getElementById('macdSignal');
    if (prediction.direction === 1) {
        macdSignal.textContent = 'Bullish';
        macdSignal.className = 'indicator-signal bullish';
    } else if (prediction.direction === -1) {
        macdSignal.textContent = 'Bearish';
        macdSignal.className = 'indicator-signal bearish';
    } else {
        macdSignal.textContent = 'Neutral';
        macdSignal.className = 'indicator-signal neutral';
    }

    // MA Cross
    const maCross = document.getElementById('maCross');
    maCross.textContent = prediction.direction >= 0 ? 'Bullish' : 'Bearish';
    maCross.className = `indicator-signal ${prediction.direction >= 0 ? 'bullish' : 'bearish'}`;

    // Trend
    const trend = document.getElementById('trendIndicator');
    trend.textContent = prediction.direction === 1 ? 'Uptrend' :
                        prediction.direction === -1 ? 'Downtrend' : 'Sideways';
    trend.className = `indicator-signal ${prediction.direction === 1 ? 'bullish' :
                       prediction.direction === -1 ? 'bearish' : 'neutral'}`;

    // Pattern
    const pattern = document.getElementById('patternSignal');
    pattern.textContent = prediction.direction !== 0 ? 'Detected' : 'None';
    pattern.className = `indicator-signal ${prediction.direction !== 0 ? 'bullish' : 'neutral'}`;

    // Market Trend
    document.getElementById('marketTrend').textContent =
        prediction.direction === 1 ? 'Bullish' :
        prediction.direction === -1 ? 'Bearish' : 'Neutral';
}

function updateSentimentGauge(sentiment) {
    const bullishPercent = ((sentiment + 1) / 2) * 100;
    const bearishPercent = 100 - bullishPercent;

    state.sentimentGauge.data.datasets[0].data = [bullishPercent, bearishPercent];
    state.sentimentGauge.update();

    document.getElementById('sentimentLabel').textContent =
        sentiment > 0.2 ? 'Bullish' : sentiment < -0.2 ? 'Bearish' : 'Neutral';

    document.getElementById('bullishBar').style.width = bullishPercent + '%';
    document.getElementById('bearishBar').style.width = bearishPercent + '%';
}

function updatePriceChart() {
    const data = generateMockPriceData(50);
    state.priceChart.data.datasets[0].data = data;
    state.priceChart.update();
}

function updateAnalysisDisplay(analysis) {
    document.getElementById('analysisContent').innerHTML = `
        <p>${analysis.analysis || analysis.text}</p>
        <h4>Recommendation</h4>
        <p>${analysis.recommendation}</p>
        <h4>Current Trend</h4>
        <p>${analysis.trend}</p>
    `;

    // Update levels
    const resistanceLevels = document.getElementById('resistanceLevels');
    const supportLevels = document.getElementById('supportLevels');

    if (analysis.key_levels) {
        resistanceLevels.innerHTML = analysis.key_levels.resistance
            .map(level => `<li>${level.toFixed(5)}</li>`).join('');
        supportLevels.innerHTML = analysis.key_levels.support
            .map(level => `<li>${level.toFixed(5)}</li>`).join('');
    }
}

function updateNewsDisplay(data) {
    const newsList = document.getElementById('newsList');
    const news = data.news || generateMockNewsItems();

    newsList.innerHTML = news.map(item => `
        <div class="news-item">
            <h4>${item.title}</h4>
            <p>${item.content}</p>
            <div class="news-meta">
                <span>${item.source}</span>
                <span class="news-sentiment ${item.sentiment > 0 ? 'positive' : item.sentiment < 0 ? 'negative' : ''}">
                    <i class="fas fa-${item.sentiment > 0 ? 'arrow-up' : item.sentiment < 0 ? 'arrow-down' : 'minus'}"></i>
                    ${item.sentiment > 0 ? 'Positive' : item.sentiment < 0 ? 'Negative' : 'Neutral'}
                </span>
            </div>
        </div>
    `).join('');
}

function addToSignalHistory(prediction) {
    const signal = {
        time: new Date().toLocaleString(),
        symbol: state.currentSymbol,
        direction: prediction.direction === 1 ? 'BUY' : prediction.direction === -1 ? 'SELL' : 'HOLD',
        confidence: (prediction.confidence * 100).toFixed(1) + '%',
        entry: prediction.price_target?.toFixed(5) || '--',
        sl: prediction.stop_loss?.toFixed(5) || '--',
        tp: prediction.take_profit?.toFixed(5) || '--',
        status: 'Active'
    };

    state.signalHistory.unshift(signal);
    if (state.signalHistory.length > 50) {
        state.signalHistory.pop();
    }

    updateSignalHistoryTable();
}

function updateSignalHistoryTable() {
    const tbody = document.getElementById('signalsTableBody');
    tbody.innerHTML = state.signalHistory.map(signal => `
        <tr>
            <td>${signal.time}</td>
            <td>${signal.symbol}</td>
            <td><span class="badge ${signal.direction.toLowerCase()}">${signal.direction}</span></td>
            <td>${signal.confidence}</td>
            <td>${signal.entry}</td>
            <td>${signal.sl}</td>
            <td>${signal.tp}</td>
            <td>${signal.status}</td>
        </tr>
    `).join('');
}

// Settings
function loadSettings() {
    document.getElementById('apiUrl').value = CONFIG.apiUrl;
    document.getElementById('apiKey').value = CONFIG.apiKey;
    document.getElementById('minConfidence').value = CONFIG.minConfidence;
    document.getElementById('minConfidenceValue').textContent = CONFIG.minConfidence + '%';
    document.getElementById('autoRefresh').value = CONFIG.autoRefresh;
    document.getElementById('soundAlerts').checked = CONFIG.soundAlerts;
    document.getElementById('browserNotifications').checked = CONFIG.browserNotifications;
}

function saveSettings() {
    CONFIG.apiUrl = document.getElementById('apiUrl').value;
    CONFIG.apiKey = document.getElementById('apiKey').value;

    localStorage.setItem('apiUrl', CONFIG.apiUrl);
    localStorage.setItem('apiKey', CONFIG.apiKey);

    showToast('Settings saved successfully', 'success');
    testConnection();
}

// Utility Functions
function getHeaders() {
    const headers = {
        'Content-Type': 'application/json'
    };
    if (CONFIG.apiKey) {
        headers['Authorization'] = `Bearer ${CONFIG.apiKey}`;
    }
    return headers;
}

function showLoading() {
    elements.loadingOverlay.classList.add('active');
}

function hideLoading() {
    elements.loadingOverlay.classList.remove('active');
}

function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <i class="fas fa-${type === 'success' ? 'check-circle' :
                          type === 'error' ? 'times-circle' :
                          type === 'warning' ? 'exclamation-circle' : 'info-circle'}"></i>
        <span>${message}</span>
    `;

    elements.toastContainer.appendChild(toast);

    setTimeout(() => {
        toast.remove();
    }, 5000);
}

function startAutoRefresh() {
    if (state.refreshInterval) {
        clearInterval(state.refreshInterval);
    }

    if (CONFIG.autoRefresh > 0) {
        state.refreshInterval = setInterval(() => {
            if (state.isConnected) {
                fetchPrediction();
            }
        }, CONFIG.autoRefresh * 1000);
    }
}

function playAlertSound() {
    // Create audio context for alert sound
    try {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const oscillator = audioContext.createOscillator();
        const gainNode = audioContext.createGain();

        oscillator.connect(gainNode);
        gainNode.connect(audioContext.destination);

        oscillator.frequency.value = 800;
        oscillator.type = 'sine';
        gainNode.gain.value = 0.3;

        oscillator.start();
        oscillator.stop(audioContext.currentTime + 0.2);
    } catch (e) {
        console.log('Audio not supported');
    }
}

function requestNotificationPermission() {
    if ('Notification' in window) {
        Notification.requestPermission();
    }
}

function showNotification(prediction) {
    if ('Notification' in window && Notification.permission === 'granted') {
        const signal = prediction.direction === 1 ? 'BUY' :
                       prediction.direction === -1 ? 'SELL' : 'HOLD';
        new Notification('Trading Signal', {
            body: `${signal} ${state.currentSymbol} - ${(prediction.confidence * 100).toFixed(1)}% confidence`,
            icon: '/favicon.ico'
        });
    }
}

// Mock Data Generators
function generateMockPriceData(count) {
    const data = [];
    let price = 1.0850;

    for (let i = 0; i < count; i++) {
        price += (Math.random() - 0.5) * 0.002;
        data.push(price);
    }

    return data;
}

function generateTimeLabels(count) {
    const labels = [];
    const now = new Date();

    for (let i = count - 1; i >= 0; i--) {
        const time = new Date(now - i * 3600000);
        labels.push(time.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }));
    }

    return labels;
}

function generateMockMarketData() {
    const count = 100;
    const open = [], high = [], low = [], close = [], volume = [];
    let price = 1.0850;

    for (let i = 0; i < count; i++) {
        const change = (Math.random() - 0.5) * 0.002;
        const o = price;
        const c = price + change;
        const h = Math.max(o, c) + Math.random() * 0.001;
        const l = Math.min(o, c) - Math.random() * 0.001;

        open.push(o);
        high.push(h);
        low.push(l);
        close.push(c);
        volume.push(Math.floor(Math.random() * 10000));

        price = c;
    }

    return { open, high, low, close, volume };
}

function generateMockPrediction() {
    const direction = Math.random() > 0.6 ? 1 : Math.random() > 0.5 ? -1 : 0;
    const confidence = 0.5 + Math.random() * 0.4;
    const currentPrice = 1.0850;

    return {
        direction,
        confidence,
        sentiment: (Math.random() - 0.5) * 2,
        price_target: currentPrice + (direction * 0.005),
        stop_loss: currentPrice - (direction * 0.003),
        take_profit: currentPrice + (direction * 0.008),
        reason: `${direction === 1 ? 'Bullish' : direction === -1 ? 'Bearish' : 'Neutral'} momentum detected. Technical indicators suggest ${direction === 1 ? 'upward' : direction === -1 ? 'downward' : 'sideways'} movement with ${(confidence * 100).toFixed(0)}% probability.`,
        indicators: {
            rsi: 30 + Math.random() * 40,
            macd: (Math.random() - 0.5) * 0.001
        }
    };
}

function generateMockAnalysis() {
    return {
        text: `Market analysis for ${state.currentSymbol} on ${state.currentTimeframe} timeframe shows mixed signals. Price is currently testing key support levels with moderate momentum.`,
        recommendation: 'Wait for clear breakout above resistance before entering long positions. Consider scaling into positions on pullbacks to support.',
        trend: 'Neutral with bullish bias',
        key_levels: {
            resistance: [1.0900, 1.0950, 1.1000],
            support: [1.0800, 1.0750, 1.0700]
        }
    };
}

function generateMockNews() {
    return {
        sentiment: Math.random() - 0.5,
        summary: 'Market sentiment is balanced with mixed signals from economic data.',
        news: generateMockNewsItems()
    };
}

function generateMockNewsItems() {
    return [
        {
            title: 'Federal Reserve signals patience on rate decisions',
            content: 'Fed officials indicated they are in no rush to adjust interest rates, maintaining current policy stance.',
            source: 'Financial Times',
            sentiment: 0.1
        },
        {
            title: 'European markets steady ahead of ECB meeting',
            content: 'Traders await ECB decision as inflation data comes in mixed across eurozone.',
            source: 'Reuters',
            sentiment: 0
        },
        {
            title: 'Asian markets rise on positive economic data',
            content: 'Regional indices gain as manufacturing PMI beats expectations.',
            source: 'Bloomberg',
            sentiment: 0.3
        }
    ];
}

// Initialize economic calendar
function initCalendar() {
    const tbody = document.getElementById('calendarTableBody');
    const events = [
        { date: 'Today 14:30', currency: 'USD', event: 'Non-Farm Payrolls', impact: 'high', previous: '216K', forecast: '200K' },
        { date: 'Tomorrow 12:00', currency: 'EUR', event: 'ECB Interest Rate Decision', impact: 'high', previous: '4.50%', forecast: '4.50%' },
        { date: 'Dec 26 09:00', currency: 'GBP', event: 'UK GDP', impact: 'medium', previous: '0.2%', forecast: '0.3%' },
        { date: 'Dec 27 03:00', currency: 'JPY', event: 'BOJ Policy Statement', impact: 'high', previous: '-', forecast: '-' }
    ];

    tbody.innerHTML = events.map(event => `
        <tr>
            <td>${event.date}</td>
            <td>${event.currency}</td>
            <td>${event.event}</td>
            <td><span class="badge ${event.impact}">${event.impact}</span></td>
            <td>${event.previous}</td>
            <td>${event.forecast}</td>
        </tr>
    `).join('');
}

// Call calendar init
initCalendar();
updateNewsDisplay(generateMockNews());
