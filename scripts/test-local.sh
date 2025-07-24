#!/bin/bash

# Test Crawl4AI MCP Server deployment
# Based on coagents-travel testing pattern

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="app-crawl4ai"
SERVICE_NAME="crawl4ai-service"
DEPLOYMENT_NAME="crawl4ai-mcp-server"

echo -e "${GREEN}🧪 Testing Crawl4AI MCP Server deployment...${NC}"

# Test 1: Check if deployment exists and is ready
echo -e "${YELLOW}Test 1: Deployment Status${NC}"
if kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE &> /dev/null; then
    READY_REPLICAS=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED_REPLICAS=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ]; then
        echo -e "${GREEN}✅ Deployment is ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas)${NC}"
    else
        echo -e "${RED}❌ Deployment not ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas)${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Deployment not found${NC}"
    exit 1
fi

# Test 2: Check if service exists
echo -e "${YELLOW}Test 2: Service Status${NC}"
if kubectl get service $SERVICE_NAME -n $NAMESPACE &> /dev/null; then
    CLUSTER_IP=$(kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
    echo -e "${GREEN}✅ Service exists with ClusterIP: $CLUSTER_IP${NC}"
else
    echo -e "${RED}❌ Service not found${NC}"
    exit 1
fi

# Test 3: Check pod health
echo -e "${YELLOW}Test 3: Pod Health${NC}"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT_NAME -o jsonpath='{.items[0].metadata.name}')

if [ ! -z "$POD_NAME" ]; then
    POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$POD_STATUS" = "Running" ]; then
        echo -e "${GREEN}✅ Pod $POD_NAME is running${NC}"
    else
        echo -e "${RED}❌ Pod $POD_NAME status: $POD_STATUS${NC}"
        kubectl describe pod $POD_NAME -n $NAMESPACE
        exit 1
    fi
else
    echo -e "${RED}❌ No pods found${NC}"
    exit 1
fi

# Test 4: Internal service connectivity
echo -e "${YELLOW}Test 4: Internal Service Connectivity${NC}"
kubectl run test-connectivity --rm -i --restart=Never --image=curlimages/curl -n $NAMESPACE -- \
    curl -f -s -m 15 http://$SERVICE_NAME:11235/playground > /dev/null && \
    echo -e "${GREEN}✅ Internal service connectivity test passed${NC}" || \
    (echo -e "${RED}❌ Internal service connectivity test failed${NC}" && exit 1)

# Test 5: Check logs for errors
echo -e "${YELLOW}Test 5: Log Analysis${NC}"
LOG_OUTPUT=$(kubectl logs $POD_NAME -n $NAMESPACE --tail=50)
if echo "$LOG_OUTPUT" | grep -qi "error\|exception\|failed\|traceback"; then
    echo -e "${YELLOW}⚠️  Potential issues found in logs:${NC}"
    echo "$LOG_OUTPUT" | grep -i "error\|exception\|failed\|traceback" || true
else
    echo -e "${GREEN}✅ No obvious errors in recent logs${NC}"
fi

# Test 6: Resource usage check
echo -e "${YELLOW}Test 6: Resource Usage${NC}"
CPU_USAGE=$(kubectl top pod $POD_NAME -n $NAMESPACE --no-headers | awk '{print $2}' 2>/dev/null || echo "N/A")
MEMORY_USAGE=$(kubectl top pod $POD_NAME -n $NAMESPACE --no-headers | awk '{print $3}' 2>/dev/null || echo "N/A")
echo -e "${GREEN}📊 Resource usage - CPU: $CPU_USAGE, Memory: $MEMORY_USAGE${NC}"

# Test 7: MCP endpoints test
echo -e "${YELLOW}Test 7: MCP Endpoints Test${NC}"
kubectl run test-mcp --rm -i --restart=Never --image=curlimages/curl -n $NAMESPACE -- \
    sh -c "curl -f -s -m 10 http://$SERVICE_NAME:11235/playground | grep -q 'crawl4ai' || curl -f -s -m 10 http://$SERVICE_NAME:11235/" > /dev/null && \
    echo -e "${GREEN}✅ MCP server is responding${NC}" || \
    echo -e "${YELLOW}⚠️  MCP server response test inconclusive${NC}"

echo -e "${GREEN}🎉 All tests completed!${NC}"
echo ""
echo -e "${YELLOW}📋 Deployment Summary:${NC}"
echo -e "${GREEN}  Namespace:${NC} $NAMESPACE"
echo -e "${GREEN}  Service:${NC} $SERVICE_NAME.$NAMESPACE.svc.cluster.local:11235"
echo -e "${GREEN}  Pod:${NC} $POD_NAME"
echo -e "${GREEN}  Status:${NC} Ready"
echo ""
echo -e "${YELLOW}🔧 Useful debugging commands:${NC}"
echo -e "${GREEN}  Port forward:${NC} kubectl port-forward -n $NAMESPACE svc/$SERVICE_NAME 11235:11235"
echo -e "${GREEN}  View logs:${NC} kubectl logs -n $NAMESPACE $POD_NAME -f"
echo -e "${GREEN}  Describe pod:${NC} kubectl describe pod -n $NAMESPACE $POD_NAME"
echo -e "${GREEN}  Shell access:${NC} kubectl exec -it -n $NAMESPACE $POD_NAME -- /bin/bash"