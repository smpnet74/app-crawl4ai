# Crawl4AI MCP Server Deployment

This project deploys the [Crawl4AI MCP Server](https://github.com/unclecode/crawl4ai) to Kubernetes for internal cluster use.

## Overview

The Crawl4AI MCP Server provides web crawling and AI-powered content extraction capabilities through the Model Context Protocol (MCP). This deployment is configured for:

- **Internal cluster access only** (no external exposure)
- **Prebuilt Docker image** (`unclecode/crawl4ai:0.7.0-r1`)
- **High availability** with 2 replicas and anti-affinity
- **Session persistence** for MCP connections
- **Secure configuration** with API keys stored as Kubernetes secrets

## Architecture

```
┌─────────────────────────┐
│   Internal Applications │
└────────────┬────────────┘
             │
             │ MCP Protocol
             │
┌────────────▼────────────┐
│  crawl4ai-service       │
│  (ClusterIP)            │
│  Port: 11235            │
└────────────┬────────────┘
             │
             │
┌────────────▼────────────┐
│  crawl4ai-mcp-server    │
│  (Deployment)           │
│  Replicas: 2            │
│  Image: unclecode/      │
│         crawl4ai:0.7.0-r1│
└─────────────────────────┘
```

## Prerequisites

- Kubernetes cluster with kubectl access
- OpenAI API key (required)
- Optional: Anthropic API key, Google API key

## Quick Start

1. **Clone and setup environment:**
   ```bash
   cd /Users/scottpeterson/xdev/app-crawl4ai
   cp .env.example .env
   # Edit .env with your API keys
   ```

2. **Deploy to cluster:**
   ```bash
   ./scripts/deploy-k8s.sh
   ```

3. **Test deployment:**
   ```bash
   ./scripts/test-local.sh
   ```

4. **Access the service:**
   ```bash
   # Port forward for local testing
   kubectl port-forward -n app-crawl4ai svc/crawl4ai-service 11235:11235
   
   # Visit http://localhost:11235/playground
   ```

## Service Access

The MCP server is available internally at:
- **Service URL:** `crawl4ai-service.app-crawl4ai.svc.cluster.local:11235`
- **Playground:** `http://crawl4ai-service.app-crawl4ai.svc.cluster.local:11235/playground`

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes | OpenAI API key for AI operations |
| `ANTHROPIC_API_KEY` | No | Optional Anthropic API key |
| `GOOGLE_API_KEY` | No | Optional Google API key |

### Resource Limits

- **CPU:** 200m request, 500m limit
- **Memory:** 512Mi request, 1Gi limit
- **Replicas:** 2 with anti-affinity

## GitHub Actions Deployment

The project includes automated deployment via GitHub Actions:

1. **Set up secrets:**
   - `KUBECONFIG`: Base64 encoded kubeconfig file
   - `OPENAI_API_KEY`: Your OpenAI API key
   - `ANTHROPIC_API_KEY`: (Optional) Your Anthropic API key
   - `GOOGLE_API_KEY`: (Optional) Your Google API key

2. **Trigger deployment:**
   - Push to `main` branch
   - Create pull request

## MCP Integration

Other applications in the cluster can connect to the MCP server:

```python
# Example MCP client connection
MCP_SERVER_URL = "http://crawl4ai-service.app-crawl4ai.svc.cluster.local:11235"

# WebSocket endpoint
WS_ENDPOINT = "ws://crawl4ai-service.app-crawl4ai.svc.cluster.local:11235/mcp/ws"

# Server-Sent Events endpoint  
SSE_ENDPOINT = "http://crawl4ai-service.app-crawl4ai.svc.cluster.local:11235/mcp/sse"
```

## Monitoring

### Useful Commands

```bash
# Monitor deployment
kubectl get pods -n app-crawl4ai -w

# View logs
kubectl logs -n app-crawl4ai deployment/crawl4ai-mcp-server -f

# Check service status
kubectl get svc -n app-crawl4ai

# Test connectivity
kubectl run test-pod --rm -i --restart=Never --image=curlimages/curl -n app-crawl4ai -- \
  curl -f http://crawl4ai-service:11235/playground
```

### Health Checks

The deployment includes:
- **Liveness probe:** `/playground` endpoint (30s interval)
- **Readiness probe:** `/playground` endpoint (10s interval)  
- **Startup probe:** `/playground` endpoint (10s interval, 12 failures)

## Troubleshooting

### Common Issues

1. **Pods not starting:**
   ```bash
   kubectl describe pods -n app-crawl4ai
   kubectl logs -n app-crawl4ai deployment/crawl4ai-mcp-server
   ```

2. **Service not accessible:**
   ```bash
   kubectl get endpoints -n app-crawl4ai
   kubectl port-forward -n app-crawl4ai svc/crawl4ai-service 11235:11235
   ```

3. **Missing API keys:**
   ```bash
   kubectl get secrets -n app-crawl4ai
   kubectl describe secret crawl4ai-secrets -n app-crawl4ai
   ```

### Log Analysis

Check for common error patterns:
```bash
kubectl logs -n app-crawl4ai deployment/crawl4ai-mcp-server | grep -i "error\|exception\|failed"
```

## Security

- **Non-root containers:** All containers run as user 1000
- **Secret management:** API keys stored as Kubernetes secrets
- **Network isolation:** Service mesh integration with Istio Ambient
- **Resource limits:** CPU and memory limits enforced

## Integration with Cluster Applications

This MCP server is designed to be used by other applications deployed in the same Kubernetes cluster, such as:

- **AI/ML workloads** requiring web content
- **Data pipeline applications**
- **Chatbots and assistants**
- **Research and analysis tools**

Applications can connect using standard HTTP/WebSocket protocols to access crawling and content extraction capabilities.