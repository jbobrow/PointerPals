# PointerPals WebSocket Server

A lightweight WebSocket server for real-time cursor position sharing.

## Quick Start

### Prerequisites

- Node.js 14.x or later
- npm or yarn

### Installation

1. Navigate to the Server directory:
```bash
cd Server
```

2. Install dependencies:
```bash
npm install
```

### Running the Server

**Development mode** (with auto-restart):
```bash
npm run dev
```

**Production mode**:
```bash
npm start
```

The server will start on `ws://localhost:8080`

## Configuration

Edit `server.js` to change the port:
```javascript
const wss = new WebSocket.Server({ port: 8080 }); // Change port here
```

## Protocol

The server uses a JSON-based protocol over WebSocket:

### Client -> Server Messages

#### Register
```json
{
  "action": "register",
  "userId": "user_abc123",
  "username": "Alice"
}
```

#### Subscribe to User
```json
{
  "action": "subscribe",
  "targetUserId": "user_xyz789"
}
```

#### Unsubscribe from User
```json
{
  "action": "unsubscribe",
  "targetUserId": "user_xyz789"
}
```

#### Publish Cursor Update
```json
{
  "action": "cursor_update",
  "cursorData": {
    "userId": "user_abc123",
    "username": "Alice",
    "x": 0.5,
    "y": 0.3,
    "timestamp": "2024-01-14T12:00:00.000Z"
  }
}
```

### Server -> Client Messages

#### Registration Confirmation
```json
{
  "type": "registered",
  "userId": "user_abc123",
  "username": "Alice",
  "message": "Successfully connected to PointerPals server"
}
```

#### Subscription Confirmation
```json
{
  "type": "subscribed",
  "targetUserId": "user_xyz789"
}
```

#### Cursor Update
```json
{
  "type": "cursor_update",
  "cursorData": {
    "userId": "user_xyz789",
    "username": "Bob",
    "x": 0.5,
    "y": 0.3,
    "timestamp": "2024-01-14T12:00:00.000Z"
  }
}
```

#### Error
```json
{
  "type": "error",
  "message": "Error description"
}
```

## Features

- ✅ User registration with usernames
- ✅ Publish/Subscribe pattern
- ✅ Real-time cursor broadcasting
- ✅ Automatic cleanup of stale connections
- ✅ Connection health monitoring
- ✅ Graceful shutdown

## Cloud Hosting

**📘 [Google Cloud Hosting Guide](./GOOGLE_CLOUD_HOSTING.md)**

See the complete guide for deploying to Google Cloud Platform using:
- Cloud Run (Recommended - easiest and most cost-effective)
- Compute Engine (Traditional VM)
- Kubernetes Engine (Production-scale)

## Production Deployment

### Using PM2

1. Install PM2:
```bash
npm install -g pm2
```

2. Start the server:
```bash
pm2 start server.js --name pointerpals-server
```

3. Save the process list:
```bash
pm2 save
```

4. Configure PM2 to start on boot:
```bash
pm2 startup
```

### Using Docker

Create a `Dockerfile`:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY server.js ./
EXPOSE 8080
CMD ["node", "server.js"]
```

Build and run:
```bash
docker build -t pointerpals-server .
docker run -p 8080:8080 pointerpals-server
```

### Environment Variables

For production, use environment variables:

```javascript
const port = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port });
```

### SSL/TLS (WSS)

For secure WebSocket connections, use a reverse proxy like nginx:

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

## Security Considerations

⚠️ **This is a basic implementation.** For production use:

1. **Authentication**: Implement user authentication
2. **Rate Limiting**: Prevent spam and abuse
3. **Authorization**: Verify subscription permissions
4. **Input Validation**: Validate all incoming data
5. **HTTPS/WSS**: Use secure connections
6. **CORS**: Configure appropriate CORS policies
7. **Monitoring**: Add logging and monitoring

## Performance

- Handles thousands of concurrent connections
- Low latency (~10-50ms depending on network)
- Minimal CPU usage
- Memory scales with active connections

## Monitoring

The server logs:
- Connection events
- Registration/subscription events
- Active connection count (every 60 seconds)
- Error events

## Troubleshooting

### Connection refused
- Check that the server is running
- Verify the port is not in use: `lsof -i :8080`
- Check firewall settings

### High memory usage
- Monitor active connections
- Implement connection limits
- Add message rate limiting

### Messages not being delivered
- Check that users are properly registered
- Verify subscription relationships
- Review server logs for errors

## Development

### Running Tests
```bash
# Install test dependencies
npm install --save-dev jest

# Run tests
npm test
```

### Logging Levels
Add debug logging:
```javascript
const DEBUG = process.env.DEBUG === 'true';

if (DEBUG) {
  console.log('Debug message');
}
```

## License

MIT
