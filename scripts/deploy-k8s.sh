#!/bin/bash

# Deploy Crawl4AI MCP Server to Kubernetes
# Based on coagents-travel deployment pattern

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="app-crawl4ai"
DEPLOYMENT_NAME="crawl4ai-mcp-server"
SERVICE_NAME="crawl4ai-service"

echo -e "${GREEN}🚀 Deploying Crawl4AI MCP Server to Kubernetes...${NC}"

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

# Load environment variables
if [ -f ".env" ]; then
    echo -e "${GREEN}📄 Loading environment variables from .env${NC}"
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${YELLOW}⚠️  No .env file found, using defaults${NC}"
fi

# Validate required environment variables
if [ -z "$OPENAI_API_KEY" ]; then
    echo -e "${RED}❌ OPENAI_API_KEY is required${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Create namespace
echo -e "${YELLOW}🏗️  Creating namespace...${NC}"
kubectl apply -f k8s/namespace.yaml

# Create secrets
echo -e "${YELLOW}🔐 Creating/updating secrets...${NC}"

# Delete existing secret if it exists (ignore errors)
kubectl delete secret crawl4ai-secrets -n $NAMESPACE --ignore-not-found=true

# Create new secret with environment variables
kubectl create secret generic crawl4ai-secrets \
    --from-literal=openai-api-key="${OPENAI_API_KEY}" \
    --from-literal=anthropic-api-key="${ANTHROPIC_API_KEY:-}" \
    --from-literal=google-api-key="${GOOGLE_API_KEY:-}" \
    -n $NAMESPACE

echo -e "${GREEN}✅ Secrets created successfully${NC}"

# Deploy Kubernetes resources
echo -e "${YELLOW}🚀 Deploying Kubernetes resources...${NC}"
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Wait for deployment to be ready
echo -e "${YELLOW}⏳ Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=600s

# Verify deployment
echo -e "${YELLOW}🔍 Verifying deployment...${NC}"
kubectl get pods -n $NAMESPACE
kubectl get services -n $NAMESPACE

# Check pod health
echo -e "${YELLOW}🏥 Checking pod health...${NC}"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT_NAME -o jsonpath='{.items[0].metadata.name}')

if [ ! -z "$POD_NAME" ]; then
    echo -e "${GREEN}Pod: $POD_NAME${NC}"
    
    # Wait a moment for the service to start
    sleep 10
    
    # Test internal connectivity
    echo -e "${YELLOW}🧪 Testing internal service connectivity...${NC}"
    kubectl run test-pod --rm -i --restart=Never --image=curlimages/curl -n $NAMESPACE -- \
        curl -f -s -m 10 http://$SERVICE_NAME:11235/playground && \
        echo -e "${GREEN}✅ Internal service test passed${NC}" || \
        echo -e "${YELLOW}⚠️  Internal service test failed (may be expected during startup)${NC}"
    
    # Show recent logs
    echo -e "${YELLOW}📋 Recent pod logs:${NC}"
    kubectl logs $POD_NAME -n $NAMESPACE --tail=20
else
    echo -e "${RED}❌ No pods found${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Useful commands:${NC}"
echo -e "${GREEN}  Monitor pods:${NC} kubectl get pods -n $NAMESPACE -w"
echo -e "${GREEN}  View logs:${NC} kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME -f"
echo -e "${GREEN}  Port forward:${NC} kubectl port-forward -n $NAMESPACE svc/$SERVICE_NAME 11235:11235"
echo -e "${GREEN}  Service URL:${NC} http://$SERVICE_NAME.$NAMESPACE.svc.cluster.local:11235"
echo ""
echo -e "${GREEN}🔗 Internal cluster access:${NC}"
echo -e "  Service: $SERVICE_NAME.$NAMESPACE.svc.cluster.local:11235"
echo -e "  Playground: http://$SERVICE_NAME.$NAMESPACE.svc.cluster.local:11235/playground"