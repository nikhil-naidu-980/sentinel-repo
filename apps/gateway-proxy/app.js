const express = require('express');
const axios = require('axios');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 8080;
const BACKEND_URL = process.env.BACKEND_URL || 'http://backend-service:8080';

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'gateway-proxy',
    hostname: os.hostname(),
    backend_url: BACKEND_URL,
    timestamp: new Date().toISOString()
  });
});

// Proxy all requests to backend
app.all('/*', async (req, res) => {
  try {
    console.log(`Proxying request: ${req.method} ${req.path} -> ${BACKEND_URL}${req.path}`);
    
    const response = await axios({
      method: req.method,
      url: `${BACKEND_URL}${req.path}`,
      headers: {
        ...req.headers,
        'X-Forwarded-For': req.ip,
        'X-Forwarded-Proto': req.protocol,
        'X-Forwarded-Host': req.hostname
      },
      data: req.body,
      timeout: 30000,
      validateStatus: () => true 
    });

    // Forward response from backend
    res.status(response.status).json({
      proxy: 'gateway',
      backend_response: response.data,
      backend_status: response.status
    });

  } catch (error) {
    console.error('Proxy error:', error.message);
    
    res.status(502).json({
      error: 'Bad Gateway',
      message: 'Failed to connect to backend service',
      details: error.message,
      backend_url: BACKEND_URL,
      timestamp: new Date().toISOString()
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Gateway proxy listening on port ${PORT}`);
  console.log(`Backend URL: ${BACKEND_URL}`);
  console.log(`Hostname: ${os.hostname()}`);
});
