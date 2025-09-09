/**
 * Fleet Health Monitor Dashboard
 * Starfleet OS
 */

// Initialize socket.io connection
const socket = io();

// Global state
const state = {
  nodes: [],
  alerts: [],
  metrics: {},
  settings: {
    theme: 'starfleet',
    alertSound: true,
    alertLevel: 'warning',
    refreshRate: 10
  },
  charts: {}
};

// DOM Elements
const elements = {
  currentTime: document.getElementById('current-time'),
  connectionStatus: document.getElementById('connection-status'),
  views: {
    dashboard: document.getElementById('dashboard-view'),
    nodes: document.getElementById('nodes-view'),
    alerts: document.getElementById('alerts-view'),
    metrics: document.getElementById('metrics-view'),
    settings: document.getElementById('settings-view')
  },
  dashboard: {
    fleetHealthIndicator: document.getElementById('fleet-health-indicator'),
    activeNodesCount: document.getElementById('active-nodes-count'),
    activeAlertsList: document.getElementById('active-alerts-list'),
    activeAlertsCount: document.getElementById('active-alerts-count'),
    cpuMeter: document.getElementById('cpu-meter'),
    cpuValue: document.getElementById('cpu-value'),
    memoryMeter: document.getElementById('memory-meter'),
    memoryValue: document.getElementById('memory-value'),
    storageMeter: document.getElementById('storage-meter'),
    storageValue: document.getElementById('storage-value'),
    networkMeter: document.getElementById('network-meter'),
    networkValue: document.getElementById('network-value')
  },
  nodes: {
    filters: document.querySelectorAll('.node-filters .lcars-button'),
    grid: document.getElementById('nodes-grid')
  },
  alerts: {
    filters: document.querySelectorAll('.alert-filters .lcars-button'),
    list: document.getElementById('alerts-list')
  },
  metrics: {
    metricSelect: document.getElementById('metric-select'),
    timeRangeSelect: document.getElementById('time-range-select'),
    chart: document.getElementById('metrics-chart')
  },
  settings: {
    themeSelect: document.getElementById('theme-select'),
    alertSound: document.getElementById('alert-sound'),
    alertLevel: document.getElementById('alert-level'),
    refreshRate: document.getElementById('refresh-rate'),
    saveButton: document.getElementById('save-settings'),
    resetButton: document.getElementById('reset-settings')
  },
  modal: {
    nodeDetails: document.getElementById('node-details-modal'),
    nodeDetailsTitle: document.getElementById('node-details-title'),
    nodeDetailsBody: document.getElementById('node-details-body'),
    closeButton: document.querySelector('.lcars-modal-close')
  }
};

// Initialize the dashboard
function initDashboard() {
  // Set up navigation
  setupNavigation();
  
  // Set up event listeners
  setupEventListeners();
  
  // Initialize charts
  initCharts();
  
  // Load settings from localStorage
  loadSettings();
  
  // Start clock
  updateClock();
  setInterval(updateClock, 1000);
  
  // Fetch initial data
  fetchNodes();
  fetchAlerts();
  fetchMetrics();
  
  // Set up refresh interval
  setRefreshInterval();
  
  // Set up socket listeners
  setupSocketListeners();
}

// Set up navigation between views
function setupNavigation() {
  const navButtons = document.querySelectorAll('.lcars-sidebar .lcars-button[data-view]');
  
  navButtons.forEach(button => {
    button.addEventListener('click', () => {
      const viewName = button.getAttribute('data-view');
      
      // Hide all views
      Object.values(elements.views).forEach(view => {
        view.classList.add('hidden');
      });
      
      // Show selected view
      elements.views[viewName].classList.remove('hidden');
      
      // Update active button
      navButtons.forEach(btn => btn.classList.remove('active'));
      button.classList.add('active');
    });
  });
}

// Set up event listeners
function setupEventListeners() {
  // Node filters
  elements.nodes.filters.forEach(filter => {
    filter.addEventListener('click', () => {
      const filterType = filter.getAttribute('data-filter');
      
      // Update active filter
      elements.nodes.filters.forEach(btn => btn.classList.remove('active'));
      filter.classList.add('active');
      
      // Filter nodes
      renderNodes(filterType);
    });
  });
  
  // Alert filters
  elements.alerts.filters.forEach(filter => {
    filter.addEventListener('click', () => {
      const filterType = filter.getAttribute('data-filter');
      
      // Update active filter
      elements.alerts.filters.forEach(btn => btn.classList.remove('active'));
      filter.classList.add('active');
      
      // Filter alerts
      renderAlerts(filterType);
    });
  });
  
  // Metrics controls
  elements.metrics.metricSelect.addEventListener('change', updateMetricsChart);
  elements.metrics.timeRangeSelect.addEventListener('change', updateMetricsChart);
  
  // Settings controls
  elements.settings.saveButton.addEventListener('click', saveSettings);
  elements.settings.resetButton.addEventListener('click', resetSettings);
  elements.settings.themeSelect.addEventListener('change', () => {
    applyTheme(elements.settings.themeSelect.value);
  });
  
  // Modal close button
  elements.modal.closeButton.addEventListener('click', () => {
    elements.modal.nodeDetails.classList.remove('active');
  });
  
  // Action buttons
  document.querySelector('[data-action="scan"]').addEventListener('click', scanFleet);
  document.querySelector('[data-action="alert"]').addEventListener('click', triggerRedAlert);
}

// Initialize charts
function initCharts() {
  // Fleet health chart
  const fleetHealthCtx = document.getElementById('fleet-health-chart').getContext('2d');
  state.charts.fleetHealth = new Chart(fleetHealthCtx, {
    type: 'line',
    data: {
      labels: [],
      datasets: [{
        label: 'Fleet Health',
        data: [],
        borderColor: getCSSVariable('--lcars-accent'),
        backgroundColor: getCSSVariable('--lcars-accent') + '33',
        tension: 0.4,
        fill: true
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true,
          max: 100
        }
      }
    }
  });
  
  // Nodes status chart
  const nodesStatusCtx = document.getElementById('nodes-status-chart').getContext('2d');
  state.charts.nodesStatus = new Chart(nodesStatusCtx, {
    type: 'doughnut',
    data: {
      labels: ['Online', 'Offline', 'Warning'],
      datasets: [{
        data: [0, 0, 0],
        backgroundColor: [
          getCSSVariable('--lcars-accent'),
          getCSSVariable('--lcars-danger'),
          getCSSVariable('--lcars-warning')
        ]
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'bottom'
        }
      }
    }
  });
  
  // Metrics chart
  const metricsCtx = document.getElementById('metrics-chart').getContext('2d');
  state.charts.metrics = new Chart(metricsCtx, {
    type: 'line',
    data: {
      labels: [],
      datasets: []
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true
        }
      }
    }
  });
}

// Load settings from localStorage
function loadSettings() {
  const savedSettings = localStorage.getItem('fleetHealthSettings');
  if (savedSettings) {
    try {
      const parsedSettings = JSON.parse(savedSettings);
      state.settings = { ...state.settings, ...parsedSettings };
      
      // Apply settings to UI
      elements.settings.themeSelect.value = state.settings.theme;
      elements.settings.alertSound.checked = state.settings.alertSound;
      elements.settings.alertLevel.value = state.settings.alertLevel;
      elements.settings.refreshRate.value = state.settings.refreshRate;
      
      // Apply theme
      applyTheme(state.settings.theme);
    } catch (error) {
      console.error('Error loading settings:', error);
    }
  }
}

// Save settings to localStorage
function saveSettings() {
  state.settings.theme = elements.settings.themeSelect.value;
  state.settings.alertSound = elements.settings.alertSound.checked;
  state.settings.alertLevel = elements.settings.alertLevel.value;
  state.settings.refreshRate = parseInt(elements.settings.refreshRate.value);
  
  localStorage.setItem('fleetHealthSettings', JSON.stringify(state.settings));
  
  // Apply theme
  applyTheme(state.settings.theme);
  
  // Update refresh interval
  setRefreshInterval();
  
  // Show confirmation
  showNotification('Settings saved successfully');
}

// Reset settings to defaults
function resetSettings() {
  state.settings = {
    theme: 'starfleet',
    alertSound: true,
    alertLevel: 'warning',
    refreshRate: 10
  };
  
  // Apply settings to UI
  elements.settings.themeSelect.value = state.settings.theme;
  elements.settings.alertSound.checked = state.settings.alertSound;
  elements.settings.alertLevel.value = state.settings.alertLevel;
  elements.settings.refreshRate.value = state.settings.refreshRate;
  
  // Apply theme
  applyTheme(state.settings.theme);
  
  // Update refresh interval
  setRefreshInterval();
  
  // Save to localStorage
  localStorage.setItem('fleetHealthSettings', JSON.stringify(state.settings));
  
  // Show confirmation
  showNotification('Settings reset to defaults');
}

// Apply theme
function applyTheme(theme) {
  document.body.className = `lcars-theme-${theme}`;
  
  // Update chart colors
  if (state.charts.fleetHealth) {
    state.charts.fleetHealth.data.datasets[0].borderColor = getCSSVariable('--lcars-accent');
    state.charts.fleetHealth.data.datasets[0].backgroundColor = getCSSVariable('--lcars-accent') + '33';
    state.charts.fleetHealth.update();
  }
  
  if (state.charts.nodesStatus) {
    state.charts.nodesStatus.data.datasets[0].backgroundColor = [
      getCSSVariable('--lcars-accent'),
      getCSSVariable('--lcars-danger'),
      getCSSVariable('--lcars-warning')
    ];
    state.charts.nodesStatus.update();
  }
}

// Set refresh interval
function setRefreshInterval() {
  // Clear existing interval
  if (window.refreshInterval) {
    clearInterval(window.refreshInterval);
  }
  
  // Set new interval
  window.refreshInterval = setInterval(() => {
    fetchNodes();
    fetchAlerts();
    fetchMetrics();
  }, state.settings.refreshRate * 1000);
}

// Set up socket listeners
function setupSocketListeners() {
  socket.on('connect', () => {
    elements.connectionStatus.textContent = 'CONNECTED';
    elements.connectionStatus.style.backgroundColor = getCSSVariable('--lcars-accent');
  });
  
  socket.on('disconnect', () => {
    elements.connectionStatus.textContent = 'DISCONNECTED';
    elements.connectionStatus.style.backgroundColor = getCSSVariable('--lcars-danger');
  });
  
  socket.on('node-update', (node) => {
    // Update node in state
    const index = state.nodes.findIndex(n => n.id === node.id);
    if (index !== -1) {
      state.nodes[index] = { ...state.nodes[index], ...node };
    } else {
      state.nodes.push(node);
    }
    
    // Update UI
    updateDashboardSummary();
    renderNodes();
  });
  
  socket.on('alert', (alert) => {
    // Add alert to state
    state.alerts.unshift(alert);
    
    // Update UI
    updateDashboardSummary();
    renderAlerts();
    
    // Play sound if enabled
    if (state.settings.alertSound && alert.level === 'critical') {
      playAlertSound();
    }
    
    // Show notification
    showNotification(`${alert.level.toUpperCase()}: ${alert.message}`);
  });
}

// Update clock
function updateClock() {
  const now = new Date();
  elements.currentTime.textContent = now.toLocaleTimeString();
}

// Fetch nodes data
function fetchNodes() {
  fetch('/api/nodes')
    .then(response => response.json())
    .then(data => {
      state.nodes = data;
      updateDashboardSummary();
      renderNodes();
    })
    .catch(error => {
      console.error('Error fetching nodes:', error);
    });
}

// Fetch alerts data
function fetchAlerts() {
  fetch('/api/alerts')
    .then(response => response.json())
    .then(data => {
      state.alerts = data;
      updateDashboardSummary();
      renderAlerts();
    })
    .catch(error => {
      console.error('Error fetching alerts:', error);
    });
}

// Fetch metrics data
function fetchMetrics() {
  // For demo purposes, we'll generate random metrics
  // In a real implementation, this would fetch from the API
  generateRandomMetrics();
  updateDashboardMeters();
  updateMetricsChart();
}

// Generate random metrics for demo
function generateRandomMetrics() {
  const now = new Date();
  const timestamp = now.toISOString();
  
  if (!state.metrics.timestamps) {
    state.metrics.timestamps = [];
    state.metrics.cpu = [];
    state.metrics.memory = [];
    state.metrics.disk = [];
    state.metrics.network = [];
    state.metrics.temperature = [];
  }
  
  // Add new data point
  state.metrics.timestamps.push(timestamp);
  state.metrics.cpu.push(Math.floor(Math.random() * 100));
  state.metrics.memory.push(Math.floor(Math.random() * 100));
  state.metrics.disk.push(Math.floor(50 + Math.random() * 30));
  state.metrics.network.push(Math.floor(Math.random() * 1000));
  state.metrics.temperature.push(Math.floor(40 + Math.random() * 20));
  
  // Keep only the last 60 data points
  if (state.metrics.timestamps.length > 60) {
    state.metrics.timestamps.shift();
    state.metrics.cpu.shift();
    state.metrics.memory.shift();
    state.metrics.disk.shift();
    state.metrics.network.shift();
    state.metrics.temperature.shift();
  }
  
  // Update fleet health chart
  const healthScores = state.metrics.cpu.map((cpu, i) => {
    const memory = state.metrics.memory[i];
    const disk = state.metrics.disk[i];
    const temp = state.metrics.temperature[i];
    
    // Calculate health score (0-100)
    return 100 - ((cpu + memory) / 2 * 0.5 + disk * 0.3 + (temp - 40) * 2);
  });
  
  state.charts.fleetHealth.data.labels = state.metrics.timestamps.map(t => {
    const date = new Date(t);
    return date.toLocaleTimeString();
  });
  state.charts.fleetHealth.data.datasets[0].data = healthScores;
  state.charts.fleetHealth.update();
  
  // Update fleet health indicator
  const latestHealth = healthScores[healthScores.length - 1];
  elements.dashboard.fleetHealthIndicator.textContent = getHealthStatus(latestHealth);
  elements.dashboard.fleetHealthIndicator.className = 'status-indicator ' + getHealthClass(latestHealth);
}

// Update dashboard summary
function updateDashboardSummary() {
  // Update active nodes count
  const activeNodes = state.nodes.filter(node => node.status === 'online');
  elements.dashboard.activeNodesCount.textContent = activeNodes.length;
  
  // Update nodes status chart
  const onlineCount = state.nodes.filter(node => node.status === 'online').length;
  const offlineCount = state.nodes.filter(node => node.status === 'offline').length;
  const warningCount = state.nodes.filter(node => node.status === 'warning').length;
  
  state.charts.nodesStatus.data.datasets[0].data = [onlineCount, offlineCount, warningCount];
  state.charts.nodesStatus.update();
  
  // Update active alerts
  const activeAlerts = state.alerts.filter(alert => !alert.acknowledged);
  elements.dashboard.activeAlertsCount.textContent = activeAlerts.length;
  
  if (activeAlerts.length > 0) {
    elements.dashboard.activeAlertsList.innerHTML = '';
    
    activeAlerts.slice(0, 5).forEach(alert => {
      const alertItem = document.createElement('div');
      alertItem.className = `alert-item ${alert.level}`;
      
      const alertTime = new Date(alert.timestamp).toLocaleTimeString();
      
      alertItem.innerHTML = `
        <div class="alert-message">${alert.message}</div>
        <div class="alert-time">${alertTime}</div>
      `;
      
      elements.dashboard.activeAlertsList.appendChild(alertItem);
    });
    
    if (activeAlerts.length > 5) {
      const moreItem = document.createElement('div');
      moreItem.className = 'alert-item';
      moreItem.textContent = `+ ${activeAlerts.length - 5} more alerts`;
      elements.dashboard.activeAlertsList.appendChild(moreItem);
    }
  } else {
    elements.dashboard.activeAlertsList.innerHTML = '<div class="empty-state">No active alerts</div>';
  }
}

// Update dashboard meters
function updateDashboardMeters() {
  if (state.metrics.cpu && state.metrics.cpu.length > 0) {
    const latestCpu = state.metrics.cpu[state.metrics.cpu.length - 1];
    const latestMemory = state.metrics.memory[state.metrics.memory.length - 1];
    const latestDisk = state.metrics.disk[state.metrics.disk.length - 1];
    const latestNetwork = state.metrics.network[state.metrics.network.length - 1];
    
    // Update CPU meter
    elements.dashboard.cpuMeter.style.width = `${latestCpu}%`;
    elements.dashboard.cpuValue.textContent = `${latestCpu}%`;
    elements.dashboard.cpuMeter.className = `meter-fill ${getMeterClass(latestCpu)}`;
    
    // Update Memory meter
    elements.dashboard.memoryMeter.style.width = `${latestMemory}%`;
    elements.dashboard.memoryValue.textContent = `${latestMemory}%`;
    elements.dashboard.memoryMeter.className = `meter-fill ${getMeterClass(latestMemory)}`;
    
    // Update Storage meter
    elements.dashboard.storageMeter.style.width = `${latestDisk}%`;
    elements.dashboard.storageValue.textContent = `${latestDisk}%`;
    elements.dashboard.storageMeter.className = `meter-fill ${getMeterClass(latestDisk)}`;
    
    // Update Network meter
    const networkPercent = Math.min(latestNetwork / 10, 100);
    elements.dashboard.networkMeter.style.width = `${networkPercent}%`;
    elements.dashboard.networkValue.textContent = `${latestNetwork} KB/s`;
    elements.dashboard.networkMeter.className = `meter-fill ${getMeterClass(networkPercent)}`;
  }
}

// Render nodes
function renderNodes(filter = 'all') {
  const nodesGrid = elements.nodes.grid;
  nodesGrid.innerHTML = '';
  
  let filteredNodes = state.nodes;
  
  if (filter !== 'all') {
    filteredNodes = state.nodes.filter(node => node.type === filter);
  }
  
  if (filteredNodes.length === 0) {
    nodesGrid.innerHTML = '<div class="empty-state">No nodes found</div>';
    return;
  }
  
  filteredNodes.forEach(node => {
    const nodeCard = document.createElement('div');
    nodeCard.className = 'node-card';
    nodeCard.setAttribute('data-node-id', node.id);
    
    nodeCard.innerHTML = `
      <div class="node-header">
        <div class="node-name">${node.name}</div>
        <div class="node-status ${node.status}">${node.status.toUpperCase()}</div>
      </div>
      <div class="node-type">${node.type || 'Unknown'}</div>
      <div class="node-metrics">
        <div class="node-metric">
          <span class="node-metric-label">Last Seen:</span>
          <span>${formatTimestamp(node.last_seen)}</span>
        </div>
        <div class="node-metric">
          <span class="node-metric-label">IP Address:</span>
          <span>${node.ip_address || 'Unknown'}</span>
        </div>
      </div>
    `;
    
    nodeCard.addEventListener('click', () => {
      showNodeDetails(node);
    });
    
    nodesGrid.appendChild(nodeCard);
  });
}

// Render alerts
function renderAlerts(filter = 'all') {
  const alertsList = elements.alerts.list;
  alertsList.innerHTML = '';
  
  let filteredAlerts = state.alerts;
  
  if (filter !== 'all') {
    filteredAlerts = state.alerts.filter(alert => alert.level === filter);
  }
  
  if (filteredAlerts.length === 0) {
    alertsList.innerHTML = '<div class="empty-state">No alerts found</div>';
    return;
  }
  
  filteredAlerts.forEach(alert => {
    const alertCard = document.createElement('div');
    alertCard.className = `alert-card ${alert.level}`;
    
    alertCard.innerHTML = `
      <div class="alert-header">
        <div class="alert-level ${alert.level}">${alert.level.toUpperCase()}</div>
        <div class="alert-timestamp">${formatTimestamp(alert.timestamp)}</div>
      </div>
      <div class="alert-message">${alert.message}</div>
      <div class="alert-node">Node: ${alert.node_name || 'Unknown'}</div>
      <div class="alert-actions">
        ${alert.acknowledged ? 
          '<button disabled>Acknowledged</button>' : 
          '<button class="acknowledge-btn">Acknowledge</button>'}
      </div>
    `;
    
    const acknowledgeBtn = alertCard.querySelector('.acknowledge-btn');
    if (acknowledgeBtn) {
      acknowledgeBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        acknowledgeAlert(alert.id);
      });
    }
    
    alertsList.appendChild(alertCard);
  });
}

// Update metrics chart
function updateMetricsChart() {
  const metric = elements.metrics.metricSelect.value;
  const timeRange = parseInt(elements.metrics.timeRangeSelect.value);
  
  // Get data for selected metric
  const metricData = state.metrics[metric];
  if (!metricData) return;
  
  // Filter data by time range
  const dataPoints = Math.min(metricData.length, timeRange * 60 / state.settings.refreshRate);
  const filteredData = metricData.slice(-dataPoints);
  const filteredLabels = state.metrics.timestamps.slice(-dataPoints).map(t => {
    const date = new Date(t);
    return date.toLocaleTimeString();
  });
  
  // Update chart
  state.charts.metrics.data.labels = filteredLabels;
  state.charts.metrics.data.datasets = [{
    label: getMetricLabel(metric),
    data: filteredData,
    borderColor: getCSSVariable('--lcars-primary'),
    backgroundColor: getCSSVariable('--lcars-primary') + '33',
    tension: 0.4,
    fill: true
  }];
  
  // Set y-axis based on metric
  if (metric === 'cpu' || metric === 'memory' || metric === 'disk') {
    state.charts.metrics.options.scales.y.max = 100;
    state.charts.metrics.options.scales.y.title = {
      display: true,
      text: 'Percentage (%)'
    };
  } else if (metric === 'network') {
    state.charts.metrics.options.scales.y.max = undefined;
    state.charts.metrics.options.scales.y.title = {
      display: true,
      text: 'KB/s'
    };
  } else if (metric === 'temperature') {
    state.charts.metrics.options.scales.y.max = 100;
    state.charts.metrics.options.scales.y.title = {
      display: true,
      text: '°C'
    };
  }
  
  state.charts.metrics.update();
}

// Show node details modal
function showNodeDetails(node) {
  elements.modal.nodeDetailsTitle.textContent = node.name;
  
  // Generate node details content
  let content = `
    <div class="node-details-section">
      <h4>Basic Information</h4>
      <div class="node-details-grid">
        <div class="node-detail-item">
          <div class="node-detail-label">Status</div>
          <div class="node-detail-value">${node.status.toUpperCase()}</div>
        </div>
        <div class="node-detail-item">
          <div class="node-detail-label">Type</div>
          <div class="node-detail-value">${node.type || 'Unknown'}</div>
        </div>
        <div class="node-detail-item">
          <div class="node-detail-label">IP Address</div>
          <div class="node-detail-value">${node.ip_address || 'Unknown'}</div>
        </div>
        <div class="node-detail-item">
          <div class="node-detail-label">Last Seen</div>
          <div class="node-detail-value">${formatTimestamp(node.last_seen)}</div>
        </div>
      </div>
    </div>
    
    <div class="node-details-section">
      <h4>System Resources</h4>
      <div class="node-chart-container">
        <canvas id="node-resources-chart"></canvas>
      </div>
    </div>
    
    <div class="node-details-section">
      <h4>Recent Alerts</h4>
      <div id="node-alerts-list">
        <div class="empty-state">Loading alerts...</div>
      </div>
    </div>
  `;
  
  elements.modal.nodeDetailsBody.innerHTML = content;
  elements.modal.nodeDetails.classList.add('active');
  
  // Create resources chart
  const ctx = document.getElementById('node-resources-chart').getContext('2d');
  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: ['CPU', 'Memory', 'Disk', 'Network', 'Temperature'],
      datasets: [{
        label: 'Current Usage',
        data: [
          Math.floor(Math.random() * 100),
          Math.floor(Math.random() * 100),
          Math.floor(50 + Math.random() * 30),
          Math.floor(Math.random() * 100),
          Math.floor(40 + Math.random() * 20)
        ],
        backgroundColor: [
          getCSSVariable('--lcars-primary'),
          getCSSVariable('--lcars-secondary'),
          getCSSVariable('--lcars-accent'),
          getCSSVariable('--lcars-primary'),
          getCSSVariable('--lcars-warning')
        ]
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true,
          max: 100
        }
      }
    }
  });
  
  // Load node alerts
  const nodeAlerts = state.alerts.filter(alert => alert.node_id === node.id).slice(0, 5);
  const alertsList = document.getElementById('node-alerts-list');
  
  if (nodeAlerts.length > 0) {
    alertsList.innerHTML = '';
    
    nodeAlerts.forEach(alert => {
      const alertItem = document.createElement('div');
      alertItem.className = `alert-item ${alert.level}`;
      
      alertItem.innerHTML = `
        <div class="alert-message">${alert.message}</div>
        <div class="alert-time">${formatTimestamp(alert.timestamp)}</div>
      `;
      
      alertsList.appendChild(alertItem);
    });
  } else {
    alertsList.innerHTML = '<div class="empty-state">No alerts for this node</div>';
  }
}

// Acknowledge alert
function acknowledgeAlert(alertId) {
  // In a real implementation, this would call the API
  console.log(`Acknowledging alert ${alertId}`);
  
  // Update alert in state
  const index = state.alerts.findIndex(alert => alert.id === alertId);
  if (index !== -1) {
    state.alerts[index].acknowledged = true;
    
    // Update UI
    renderAlerts(document.querySelector('.alert-filters .lcars-button.active').getAttribute('data-filter'));
    updateDashboardSummary();
    
    // Show confirmation
    showNotification('Alert acknowledged');
  }
}

// Scan fleet
function scanFleet() {
  // In a real implementation, this would trigger a fleet scan
  console.log('Scanning fleet...');
  showNotification('Fleet scan initiated');
  
  // Simulate scan completion
  setTimeout(() => {
    showNotification('Fleet scan complete');
    fetchNodes();
  }, 3000);
}

// Trigger red alert
function triggerRedAlert() {
  // In a real implementation, this would trigger a red alert
  console.log('RED ALERT!');
  
  // Play alert sound
  playAlertSound();
  
  // Flash the screen
  document.body.classList.add('red-alert');
  setTimeout(() => {
    document.body.classList.remove('red-alert');
  }, 500);
  
  // Create alert
  const alert = {
    id: Date.now(),
    level: 'critical',
    message: 'RED ALERT: Manual alert triggered by operator',
    timestamp: new Date().toISOString(),
    node_id: null,
    node_name: 'System',
    acknowledged: false
  };
  
  // Add to state
  state.alerts.unshift(alert);
  
  // Update UI
  updateDashboardSummary();
  renderAlerts();
  
  // Show notification
  showNotification('RED ALERT ACTIVATED');
}

// Play alert sound
function playAlertSound() {
  // In a real implementation, this would play a sound
  console.log('Playing alert sound');
}

// Show notification
function showNotification(message) {
  // Create notification element
  const notification = document.createElement('div');
  notification.className = 'lcars-notification';
  notification.textContent = message;
  
  // Add to document
  document.body.appendChild(notification);
  
  // Animate in
  setTimeout(() => {
    notification.classList.add('active');
  }, 10);
  
  // Remove after delay
  setTimeout(() => {
    notification.classList.remove('active');
    setTimeout(() => {
      notification.remove();
    }, 300);
  }, 3000);
}

// Helper functions
function formatTimestamp(timestamp) {
  if (!timestamp) return 'Never';
  
  const date = new Date(timestamp);
  return date.toLocaleString();
}

function getHealthStatus(score) {
  if (score >= 80) return 'NOMINAL';
  if (score >= 60) return 'ACCEPTABLE';
  if (score >= 40) return 'DEGRADED';
  return 'CRITICAL';
}

function getHealthClass(score) {
  if (score >= 80) return 'nominal';
  if (score >= 60) return '';
  if (score >= 40) return 'warning';
  return 'critical';
}

function getMeterClass(value) {
  if (value < 70) return '';
  if (value < 90) return 'warning';
  return 'danger';
}

function getMetricLabel(metric) {
  switch (metric) {
    case 'cpu': return 'CPU Usage (%)';
    case 'memory': return 'Memory Usage (%)';
    case 'disk': return 'Disk Usage (%)';
    case 'network': return 'Network Traffic (KB/s)';
    case 'temperature': return 'Temperature (°C)';
    default: return metric;
  }
}

function getCSSVariable(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

// Initialize the dashboard when the DOM is loaded
document.addEventListener('DOMContentLoaded', initDashboard);