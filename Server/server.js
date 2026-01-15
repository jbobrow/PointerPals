// PointerPals WebSocket Server
// Simple Node.js server for cursor position sharing

const WebSocket = require('ws');
const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });

// Store active connections: userId -> {ws: WebSocket, username: String}
const clients = new Map();

// Store subscriptions: userId -> Set<subscribedToUserIds>
const subscriptions = new Map();

console.log(`PointerPals WebSocket Server running on port ${PORT}`);

wss.on('connection', (ws, req) => {
  console.log('New connection from:', req.socket.remoteAddress);
  
  let currentUserId = null;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      
      switch (data.action) {
        case 'register':
          // Register a new user
          currentUserId = data.userId;
          const username = data.username || 'User';
          clients.set(currentUserId, { ws, username });

          if (!subscriptions.has(currentUserId)) {
            subscriptions.set(currentUserId, new Set());
          }

          console.log(`User registered: ${currentUserId} (${username})`);

          ws.send(JSON.stringify({
            type: 'registered',
            userId: currentUserId,
            username: username,
            message: 'Successfully connected to PointerPals server'
          }));
          break;

        case 'subscribe':
          // Subscribe to another user's cursor
          if (!currentUserId) {
            ws.send(JSON.stringify({
              type: 'error',
              message: 'Must register before subscribing'
            }));
            return;
          }
          
          const targetUserId = data.targetUserId;
          
          if (!subscriptions.has(currentUserId)) {
            subscriptions.set(currentUserId, new Set());
          }
          
          subscriptions.get(currentUserId).add(targetUserId);
          console.log(`${currentUserId} subscribed to ${targetUserId}`);
          
          ws.send(JSON.stringify({
            type: 'subscribed',
            targetUserId: targetUserId
          }));
          break;

        case 'unsubscribe':
          // Unsubscribe from a user's cursor
          if (currentUserId && subscriptions.has(currentUserId)) {
            const targetUserId = data.targetUserId;
            subscriptions.get(currentUserId).delete(targetUserId);
            console.log(`${currentUserId} unsubscribed from ${targetUserId}`);
            
            ws.send(JSON.stringify({
              type: 'unsubscribed',
              targetUserId: targetUserId
            }));
          }
          break;

        case 'cursor_update':
          // Broadcast cursor position to subscribers
          if (!currentUserId) return;

          const cursorData = data.cursorData;

          // Ensure username is included in cursor data
          const clientInfo = clients.get(currentUserId);
          if (clientInfo && clientInfo.username) {
            cursorData.username = clientInfo.username;
          }

          // Find all users who are subscribed to this user
          for (const [userId, subscribedToSet] of subscriptions.entries()) {
            if (subscribedToSet.has(currentUserId)) {
              const client = clients.get(userId);

              if (client && client.ws && client.ws.readyState === WebSocket.OPEN) {
                client.ws.send(JSON.stringify({
                  type: 'cursor_update',
                  cursorData: cursorData
                }));
              }
            }
          }
          break;

        default:
          console.log('Unknown action:', data.action);
      }
    } catch (error) {
      console.error('Error processing message:', error);
      ws.send(JSON.stringify({
        type: 'error',
        message: 'Invalid message format'
      }));
    }
  });

  ws.on('close', () => {
    if (currentUserId) {
      console.log(`User disconnected: ${currentUserId}`);
      clients.delete(currentUserId);
      subscriptions.delete(currentUserId);
    }
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// Periodic cleanup of stale connections
setInterval(() => {
  clients.forEach((client, userId) => {
    if (client.ws && client.ws.readyState === WebSocket.CLOSED) {
      console.log(`Cleaning up stale connection: ${userId}`);
      clients.delete(userId);
      subscriptions.delete(userId);
    }
  });
}, 30000); // Every 30 seconds

// Handle server shutdown gracefully
process.on('SIGINT', () => {
  console.log('\nShutting down server...');
  
  wss.clients.forEach((ws) => {
    ws.close(1000, 'Server shutting down');
  });
  
  wss.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

// Log server stats every minute
setInterval(() => {
  console.log(`Active connections: ${clients.size}`);
  console.log(`Total subscriptions: ${Array.from(subscriptions.values()).reduce((sum, set) => sum + set.size, 0)}`);
}, 60000);
