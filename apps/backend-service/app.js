const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 8080;

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'backend',
    hostname: os.hostname(),
    timestamp: new Date().toISOString()
  });
});

// Main endpoint
app.get('/*', (req, res) => {
  const response = {
    message: 'Hello from backend',
    service: 'sentinel-backend',
    hostname: os.hostname(),
    path: req.path,
    timestamp: new Date().toISOString(),
    headers: req.headers
  };
  
  console.log(`Request received: ${req.method} ${req.path} from ${req.ip}`);
  res.json(response);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend service listening on port ${PORT}`);
  console.log(`Hostname: ${os.hostname()}`);
});
