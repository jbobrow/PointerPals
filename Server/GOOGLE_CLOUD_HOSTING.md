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
- Your server code in the `Server` directory

---

## Option 1: Google Cloud Run (Recommended)

Cloud Run is the easiest and most cost-effective option for deploying containerized applications. It automatically scales based on traffic and has a generous free tier.

### Method A: Deploy via Web Console (Easiest)

This method uses GitHub integration to automatically build and deploy your server.

#### Step 1: Prepare Your Repository

1. **Create a Dockerfile** in the `Server` directory of your repository:

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

3. **Commit and push** these changes to your GitHub repository

#### Step 2: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown at the top → **New Project**
3. Enter project name: `pointerpals-server`
4. Click **Create**
5. Wait for project creation, then select it from the project dropdown

#### Step 3: Enable Billing

1. Go to [Billing](https://console.cloud.google.com/billing) in the left menu
2. Link a billing account to your project (required for Cloud Run, but you'll stay in free tier)
3. If you don't have a billing account, click **Create Account** and add payment info

#### Step 4: Deploy to Cloud Run

1. **Navigate to Cloud Run**:
   - In the Google Cloud Console, search for "Cloud Run" in the top search bar
   - Click **Cloud Run** from the results
   - Or visit: https://console.cloud.google.com/run

2. **Create a new service**:
   - Click **Create Service** (blue button)

3. **Configure deployment source**:
   - Select **Continuously deploy new revisions from a source repository**
   - Click **Set up with Cloud Build**

4. **Connect your repository**:
   - Click **Manage Connected Repositories** → **Connect Repository**
   - Choose **GitHub** → **Authenticate with GitHub**
   - Select your repository (e.g., `username/PointerPals`)
   - Click **Next**

5. **Configure build**:
   - **Branch**: Select your main branch (e.g., `main` or `master`)
   - **Build Type**: Select **Dockerfile**
   - **Source location**: Enter `/Server/Dockerfile` (path to your Dockerfile)
   - Click **Save**

6. **Configure service settings**:
   - **Service name**: `pointerpals-server`
   - **Region**: Choose closest to you (e.g., `us-central1`)
   - **Authentication**: Select **Allow unauthenticated invocations** (so clients can connect)

7. **Configure advanced settings** (click "Container, Variables & Secrets, Connections, Security"):
   - **Container** tab:
     - Container port: `8080`
     - Memory: `512 MiB` (enough for WebSocket server)
     - CPU: `1`
     - Timeout: `3600` seconds (1 hour, allows long WebSocket connections)
   - Leave other settings as default

8. **Deploy**:
   - Click **Create** at the bottom
   - Wait 2-5 minutes for build and deployment
   - You'll see build logs in real-time

#### Step 5: Get Your Server URL

1. Once deployed, you'll see your service URL at the top:
   ```
   https://pointerpals-server-xxxxx-uc.a.run.app
   ```

2. **Copy this URL** - you'll need it for your client

#### Step 6: Update Your Client

In your Swift app (PointerPalsConfig.swift):

Change:
```swift
static let serverURL = "ws://localhost:8080"
```

To (replace with your actual URL):
```swift
static let serverURL = "wss://pointerpals-server-xxxxx-uc.a.run.app"
```

**Important**: Use `wss://` instead of `ws://` for secure WebSocket connections!

#### Step 7: Test Your Connection

1. Rebuild and run your PointerPals app
2. Check if it connects to your Cloud Run server
3. View logs in Cloud Run console → **Logs** tab to see connection events

---

### Method B: Deploy via CLI (Alternative)

If you prefer command-line deployment:

1. **Install Google Cloud CLI**:
   ```bash
   # macOS
   brew install google-cloud-sdk
   ```

2. **Authenticate and set project**:
   ```bash
   gcloud auth login
   gcloud config set project pointerpals-server
   ```

3. **Deploy**:
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

---

### Updating Your Deployment

Your server will automatically redeploy when you push changes to GitHub (if using Method A).

For manual updates:
- **Web Console**: Go to Cloud Run → Select service → **Edit & Deploy New Revision**
- **CLI**: Run `gcloud run deploy pointerpals-server --source .` again

### Monitoring and Logs

**View Logs** (Web Console):
1. Go to [Cloud Run Console](https://console.cloud.google.com/run)
2. Click your service name
3. Click **Logs** tab
4. See real-time connection and error logs

**View Logs** (CLI):
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

**Web Console Method:**
1. Go to [Cloud Run Console](https://console.cloud.google.com/run)
2. Click your service → **Logs** tab
3. Look for connection errors or WebSocket upgrade failures
4. Check that authentication is set to "Allow unauthenticated invocations"
5. Verify your client is using `wss://` (not `ws://`)

**CLI Method:**
```bash
gcloud run logs tail pointerpals-server
```

### Build Failures

If your Cloud Run build fails:
1. Check the **Build History** in Cloud Run console
2. Verify Dockerfile path is correct: `/Server/Dockerfile`
3. Ensure `package.json` exists in Server directory
4. Check build logs for specific errors

### Performance Issues

**Increase Resources (Web Console):**
1. Go to Cloud Run → Select service
2. Click **Edit & Deploy New Revision**
3. Go to **Container** tab
4. Increase:
   - Memory: Try `1 GiB` instead of `512 MiB`
   - CPU: Try `2` instead of `1`
   - Max instances: Increase if you have many users
5. Click **Deploy**

**Increase Resources (CLI):**
```bash
gcloud run services update pointerpals-server \
  --memory 1Gi \
  --cpu 2 \
  --max-instances 10
```

### Debugging

**View Detailed Logs (Web Console):**
1. Cloud Run Console → Your service → **Logs**
2. Use filters:
   - Severity: Select `Error` to see only errors
   - Time range: Adjust to see recent issues
3. Click any log entry to see full details

**View Logs (CLI):**
```bash
# Cloud Run logs (last 50 entries)
gcloud run logs tail pointerpals-server --limit=50

# Compute Engine logs
gcloud compute ssh pointerpals-vm --zone=us-central1-a
sudo journalctl -u pointerpals -f

# GKE logs
kubectl logs -f deployment/pointerpals-deployment
```

### Common Errors

**"Connection closed before receiving a handshake response"**
- Server might be crashing on startup
- Check logs for Node.js errors
- Verify PORT environment variable is used in server.js

**"Service Unavailable" or 502/503 errors**
- Container might be taking too long to start
- Increase startup timeout in container settings
- Check if dependencies install correctly

**WebSocket upgrade failed**
- Ensure timeout is set to at least 3600 seconds
- Verify Cloud Run allows long-lived connections
- Check that client URL uses correct domain

---

## Next Steps

### Via Web Console

1. **Set up monitoring**:
   - Cloud Run → Your service → **Metrics** tab
   - View request count, latency, memory usage
   - Set up alerts for errors or high traffic

2. **Configure auto-scaling**:
   - Edit service → **Container** tab
   - Set **Min instances**: `0` (for cost savings)
   - Set **Max instances**: `10` (or higher for scale)

3. **Add custom domain** (optional):
   - Cloud Run → Your service → **Manage Custom Domains**
   - Map your own domain (e.g., `wss://pointerpals.yourdomain.com`)

4. **Set up continuous deployment**:
   - Already configured if using Method A!
   - Push to GitHub → Automatic build & deploy

5. **Monitor costs**:
   - Go to [Billing](https://console.cloud.google.com/billing)
   - Check spending and set budget alerts

### Additional Resources

- [Cloud Run Console](https://console.cloud.google.com/run) - Manage your services
- [Cloud Run Documentation](https://cloud.google.com/run/docs) - Full reference
- [Cloud Run Pricing Calculator](https://cloud.google.com/products/calculator) - Estimate costs
- [Cloud Build Documentation](https://cloud.google.com/build/docs) - CI/CD setup
