# Hosting PointerPals WebSocket Server on Google Cloud

This guide will walk you through deploying the PointerPals WebSocket server on Google Cloud Platform using several different approaches.

## Table of Contents
- [Option 1: Google Cloud Run (Recommended)](#option-1-google-cloud-run-recommended)
- [Option 2: Google Compute Engine](#option-2-google-compute-engine)
- [Option 3: Google Kubernetes Engine (GKE)](#option-3-google-kubernetes-engine-gke)

---

## Prerequisites

Before starting, make sure you have:
- A Google Cloud Platform account ([sign up here](https://cloud.google.com/))
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) installed on your machine
- Your server code in the `Server` directory

### Initial Setup

1. **Install Google Cloud CLI** (if not already installed):
   ```bash
   # macOS
   brew install google-cloud-sdk

   # Or download from: https://cloud.google.com/sdk/docs/install
   ```

2. **Authenticate with Google Cloud**:
   ```bash
   gcloud auth login
   ```

3. **Create a new project** (or use existing):
   ```bash
   gcloud projects create pointerpals-server --name="PointerPals Server"
   gcloud config set project pointerpals-server
   ```

4. **Enable billing** for your project:
   - Visit https://console.cloud.google.com/billing
   - Link a billing account to your project

---

## Option 1: Google Cloud Run (Recommended)

Cloud Run is the easiest and most cost-effective option for deploying containerized applications. It automatically scales based on traffic.

### Step 1: Prepare Your Application

1. **Create a Dockerfile** in the `Server` directory:

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

# Cloud Run sets the PORT environment variable
ENV PORT=8080

EXPOSE 8080

CMD ["node", "server.js"]
```

2. **Update server.js** to use the PORT environment variable:

Replace:
```javascript
const wss = new WebSocket.Server({ port: 8080 });
```

With:
```javascript
const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });
console.log(`PointerPals WebSocket Server running on port ${PORT}`);
```

### Step 2: Build and Deploy

1. **Enable required APIs**:
   ```bash
   gcloud services enable run.googleapis.com
   gcloud services enable containerregistry.googleapis.com
   ```

2. **Build and deploy in one command**:
   ```bash
   cd Server
   gcloud run deploy pointerpals-server \
     --source . \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated \
     --port 8080 \
     --memory 512Mi \
     --timeout 3600
   ```

3. **Note your service URL**:
   After deployment, you'll get a URL like:
   ```
   https://pointerpals-server-xxxxx-uc.a.run.app
   ```

4. **Update your client**:
   Change the WebSocket URL in your Swift client from `ws://localhost:8080` to:
   ```
   wss://pointerpals-server-xxxxx-uc.a.run.app
   ```
   (Note: use `wss://` instead of `ws://` for secure WebSocket)

### Updating Your Deployment

To update the server:
```bash
cd Server
gcloud run deploy pointerpals-server --source .
```

### Monitoring and Logs

View logs:
```bash
gcloud run logs tail pointerpals-server
```

---

## Option 2: Google Compute Engine

Compute Engine gives you a traditional VM where you have full control.

### Step 1: Create a VM Instance

```bash
gcloud compute instances create pointerpals-vm \
  --machine-type=e2-micro \
  --zone=us-central1-a \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=10GB \
  --tags=websocket-server
```

### Step 2: Configure Firewall

Allow WebSocket traffic on port 8080:
```bash
gcloud compute firewall-rules create allow-websocket \
  --allow=tcp:8080 \
  --target-tags=websocket-server \
  --description="Allow WebSocket connections on port 8080"
```

### Step 3: Deploy Your Application

1. **SSH into your instance**:
   ```bash
   gcloud compute ssh pointerpals-vm --zone=us-central1-a
   ```

2. **Install Node.js**:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. **Transfer your server files**:
   Exit the SSH session, then from your local machine:
   ```bash
   cd Server
   gcloud compute scp --recurse ./ pointerpals-vm:~/server --zone=us-central1-a
   ```

4. **SSH back in and start the server**:
   ```bash
   gcloud compute ssh pointerpals-vm --zone=us-central1-a
   cd ~/server
   npm install
   npm start
   ```

### Step 4: Keep Server Running with PM2

1. **Install PM2**:
   ```bash
   sudo npm install -g pm2
   ```

2. **Start server with PM2**:
   ```bash
   cd ~/server
   pm2 start server.js --name pointerpals
   pm2 save
   pm2 startup
   ```

### Get Your Server URL

```bash
gcloud compute instances describe pointerpals-vm \
  --zone=us-central1-a \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

Your WebSocket URL will be: `ws://[IP_ADDRESS]:8080`

---

## Option 3: Google Kubernetes Engine (GKE)

For production-scale deployments with high availability.

### Step 1: Create a GKE Cluster

```bash
gcloud services enable container.googleapis.com

gcloud container clusters create pointerpals-cluster \
  --num-nodes=2 \
  --machine-type=e2-small \
  --zone=us-central1-a
```

### Step 2: Build and Push Docker Image

```bash
cd Server

# Build image
docker build -t gcr.io/pointerpals-server/pointerpals-ws:v1 .

# Configure Docker for GCR
gcloud auth configure-docker

# Push to Google Container Registry
docker push gcr.io/pointerpals-server/pointerpals-ws:v1
```

### Step 3: Create Kubernetes Deployment

Create `kubernetes-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pointerpals-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pointerpals
  template:
    metadata:
      labels:
        app: pointerpals
    spec:
      containers:
      - name: pointerpals
        image: gcr.io/pointerpals-server/pointerpals-ws:v1
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: pointerpals-service
spec:
  type: LoadBalancer
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: pointerpals
```

Deploy:
```bash
kubectl apply -f kubernetes-deployment.yaml
```

### Step 4: Get Service IP

```bash
kubectl get service pointerpals-service
```

Wait for `EXTERNAL-IP` to appear, then use: `ws://[EXTERNAL-IP]:8080`

---

## Cost Estimates

### Cloud Run (Recommended for most users)
- **Free tier**: 2 million requests/month, 360,000 GB-seconds/month
- **Beyond free tier**: ~$0.40 per million requests
- **Estimated cost**: $0-5/month for light usage

### Compute Engine
- **e2-micro**: ~$7.50/month (always on)
- **e2-small**: ~$15/month (always on)
- Plus minimal networking costs

### GKE
- **Cluster management**: $0.10/hour (~$73/month)
- **e2-small nodes (x2)**: ~$30/month
- **Total**: ~$100/month minimum

---

## Security Recommendations

1. **Use WSS (Secure WebSocket)**:
   - Set up SSL/TLS certificates
   - For Cloud Run, SSL is automatic
   - For Compute Engine/GKE, use [Let's Encrypt](https://letsencrypt.org/)

2. **Add Authentication**:
   - Consider implementing token-based authentication
   - Validate user IDs on the server

3. **Rate Limiting**:
   - Implement rate limiting to prevent abuse
   - Consider using Google Cloud Armor

4. **Firewall Rules**:
   - Only allow necessary ports
   - Restrict access by IP if possible

---

## Troubleshooting

### Connection Issues
- Verify firewall rules allow WebSocket traffic
- Check server logs: `gcloud run logs tail pointerpals-server`
- Ensure client uses correct protocol (`ws://` or `wss://`)

### Performance Issues
- Increase memory/CPU allocation
- Scale up number of instances
- Consider using Cloud CDN

### Debugging
```bash
# Cloud Run logs
gcloud run logs tail pointerpals-server --limit=50

# Compute Engine logs
gcloud compute ssh pointerpals-vm --zone=us-central1-a
sudo journalctl -u pointerpals -f

# GKE logs
kubectl logs -f deployment/pointerpals-deployment
```

---

## Next Steps

1. Set up monitoring with Google Cloud Monitoring
2. Configure auto-scaling based on load
3. Implement health checks
4. Set up CI/CD with Cloud Build
5. Add environment-specific configurations

For more information, visit:
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Google Compute Engine Documentation](https://cloud.google.com/compute/docs)
- [Google Kubernetes Engine Documentation](https://cloud.google.com/kubernetes-engine/docs)
