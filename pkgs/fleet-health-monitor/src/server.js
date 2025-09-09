/**
 * Fleet Health Monitor Server
 * 
 * This server provides a dashboard for monitoring the health of the Starfleet OS fleet.
 * It collects data from all nodes in the fleet and displays it in a web interface.
 */

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');
const fs = require('fs');
const sqlite3 = require('sqlite3').verbose();
const winston = require('winston');

// Configuration
const PORT = process.env.PORT || 3000;
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '../data');
const DB_PATH = path.join(DATA_DIR, 'fleet-health.db');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

// Set up logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: path.join(DATA_DIR, 'fleet-health.log') })
  ]
});

// Initialize database
const db = new sqlite3.Database(DB_PATH, (err) => {
  if (err) {
    logger.error(`Error opening database: ${err.message}`);
    process.exit(1);
  }
  logger.info(`Connected to database at ${DB_PATH}`);
  
  // Create tables if they don't exist
  db.serialize(() => {
    db.run(`CREATE TABLE IF NOT EXISTS nodes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      type TEXT NOT NULL,
      ip_address TEXT,
      last_seen TIMESTAMP,
      status TEXT
    )`);
    
    db.run(`CREATE TABLE IF NOT EXISTS metrics (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      node_id INTEGER,
      timestamp TIMESTAMP NOT NULL,
      cpu_usage REAL,
      memory_usage REAL,
      disk_usage REAL,
      network_rx REAL,
      network_tx REAL,
      temperature REAL,
      FOREIGN KEY (node_id) REFERENCES nodes (id)
    )`);
    
    db.run(`CREATE TABLE IF NOT EXISTS alerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      node_id INTEGER,
      timestamp TIMESTAMP NOT NULL,
      level TEXT NOT NULL,
      message TEXT NOT NULL,
      acknowledged BOOLEAN DEFAULT 0,
      FOREIGN KEY (node_id) REFERENCES nodes (id)
    )`);
  });
});

// Initialize Express app
const app = express();
const server = http.createServer(app);
const io = socketIo(server);

// Serve static files
app.use(express.static(path.join(__dirname, '../public')));

// API routes
app.get('/api/nodes', (req, res) => {
  db.all('SELECT * FROM nodes', [], (err, rows) => {
    if (err) {
      logger.error(`Error fetching nodes: ${err.message}`);
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

app.get('/api/nodes/:id/metrics', (req, res) => {
  const { id } = req.params;
  const { hours } = req.query;
  const timeLimit = hours ? `AND timestamp > datetime('now', '-${hours} hours')` : '';
  
  db.all(`SELECT * FROM metrics WHERE node_id = ? ${timeLimit} ORDER BY timestamp DESC`, [id], (err, rows) => {
    if (err) {
      logger.error(`Error fetching metrics: ${err.message}`);
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

app.get('/api/alerts', (req, res) => {
  const { acknowledged } = req.query;
  const whereClause = acknowledged === 'false' ? 'WHERE acknowledged = 0' : '';
  
  db.all(`SELECT alerts.*, nodes.name as node_name FROM alerts 
          JOIN nodes ON alerts.node_id = nodes.id
          ${whereClause}
          ORDER BY timestamp DESC`, [], (err, rows) => {
    if (err) {
      logger.error(`Error fetching alerts: ${err.message}`);
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

// Socket.IO for real-time updates
io.on('connection', (socket) => {
  logger.info('Client connected');
  
  socket.on('disconnect', () => {
    logger.info('Client disconnected');
  });
});

// UDP server for receiving heartbeats
const dgram = require('dgram');
const udpServer = dgram.createSocket('udp4');

udpServer.on('error', (err) => {
  logger.error(`UDP server error: ${err.message}`);
  udpServer.close();
});

udpServer.on('message', (msg, rinfo) => {
  try {
    const data = JSON.parse(msg.toString());
    logger.debug(`Received heartbeat from ${data.node} (${rinfo.address}:${rinfo.port})`);
    
    // Update node in database
    db.run(`INSERT INTO nodes (name, type, ip_address, last_seen, status)
            VALUES (?, ?, ?, datetime('now'), 'online')
            ON CONFLICT(name) DO UPDATE SET
            ip_address = ?, last_seen = datetime('now'), status = 'online'`,
      [data.node, data.system?.platform || 'unknown', rinfo.address, rinfo.address],
      function(err) {
        if (err) {
          logger.error(`Error updating node: ${err.message}`);
          return;
        }
        
        const nodeId = this.lastID || data.node;
        
        // Store metrics
        if (data.cpu !== undefined || data.memory !== undefined) {
          db.run(`INSERT INTO metrics (node_id, timestamp, cpu_usage, memory_usage, disk_usage, network_rx, network_tx, temperature)
                  VALUES (?, datetime('now'), ?, ?, ?, ?, ?, ?)`,
            [
              nodeId,
              data.cpu || null,
              data.memory?.percent || null,
              data.disk?.percent || null,
              data.network?.bytes_recv || null,
              data.network?.bytes_sent || null,
              data.temperature?.cpu?.[0]?.current || null
            ],
            (err) => {
              if (err) {
                logger.error(`Error storing metrics: ${err.message}`);
              }
            }
          );
        }
        
        // Emit update to connected clients
        io.emit('node-update', {
          id: nodeId,
          name: data.node,
          status: 'online',
          lastSeen: new Date().toISOString()
        });
      }
    );
  } catch (err) {
    logger.error(`Error processing heartbeat: ${err.message}`);
  }
});

udpServer.on('listening', () => {
  const address = udpServer.address();
  logger.info(`UDP server listening on ${address.address}:${address.port}`);
});

udpServer.bind(8765);

// Start server
server.listen(PORT, () => {
  logger.info(`Fleet Health Monitor server listening on port ${PORT}`);
});

// Check for offline nodes periodically
setInterval(() => {
  db.run(`UPDATE nodes SET status = 'offline' 
          WHERE last_seen < datetime('now', '-5 minutes')
          AND status = 'online'`,
    function(err) {
      if (err) {
        logger.error(`Error updating offline nodes: ${err.message}`);
        return;
      }
      
      if (this.changes > 0) {
        logger.info(`Marked ${this.changes} nodes as offline`);
        
        // Get list of offline nodes
        db.all(`SELECT * FROM nodes WHERE status = 'offline'`, [], (err, rows) => {
          if (err) {
            logger.error(`Error fetching offline nodes: ${err.message}`);
            return;
          }
          
          // Create alerts for offline nodes
          rows.forEach(node => {
            db.run(`INSERT INTO alerts (node_id, timestamp, level, message)
                    VALUES (?, datetime('now'), 'warning', ?)`,
              [node.id, `Node ${node.name} is offline`],
              (err) => {
                if (err) {
                  logger.error(`Error creating alert: ${err.message}`);
                }
              }
            );
            
            // Emit update to connected clients
            io.emit('node-update', {
              id: node.id,
              name: node.name,
              status: 'offline',
              lastSeen: node.last_seen
            });
          });
        });
      }
    }
  );
}, 60000);

// Handle graceful shutdown
process.on('SIGINT', () => {
  logger.info('Shutting down...');
  server.close(() => {
    db.close();
    process.exit(0);
  });
});