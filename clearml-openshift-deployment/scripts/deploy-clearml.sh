#!/bin/bash
set -e

# ClearML OpenShift Deployment Script
# This script consolidates all the deployment steps for ClearML on OpenShift

NAMESPACE="${NAMESPACE:-clearml}"
RELEASE_NAME="${RELEASE_NAME:-clearml}"
VALUES_FILE="${VALUES_FILE:-../config/values-openshift.yaml}"

echo "🚀 ClearML OpenShift Deployment Script"
echo "======================================"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "Values File: $VALUES_FILE"
echo ""

# Function to wait for pods
wait_for_pods() {
    local label_selector="$1"
    local timeout="${2:-300}"
    
    echo "⏳ Waiting for pods with selector '$label_selector' to be ready..."
    oc wait --for=condition=ready pod -l "$label_selector" -n "$NAMESPACE" --timeout="${timeout}s" || true
}

# Function to check deployment status
check_deployment_status() {
    echo "📊 Current deployment status:"
    oc get pods -n "$NAMESPACE" | grep -E "(apiserver|elasticsearch|mongodb|redis|fileserver|webserver)" || true
    echo ""
}

# Main deployment function
deploy_clearml() {
    echo "🔧 Starting ClearML deployment..."
    
    # Create namespace if it doesn't exist
    oc create namespace "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
    
    # Deploy ClearML with Helm
    echo "📦 Deploying ClearML with Helm..."
    helm upgrade --install "$RELEASE_NAME" \
        ../../clearml-helm-charts-main/charts/clearml/ \
        --namespace "$NAMESPACE" \
        --values "$VALUES_FILE" \
        --wait \
        --timeout=10m
    
    echo "✅ Helm deployment completed!"
    
    # Check initial status
    check_deployment_status
    
    # Wait for core infrastructure
    echo "⏳ Waiting for core infrastructure..."
    wait_for_pods "app.kubernetes.io/name=elasticsearch" 120
    wait_for_pods "app.kubernetes.io/name=mongodb" 120
    wait_for_pods "app.kubernetes.io/name=redis" 120
    
    # Wait for API server asyncdelete (usually starts first)
    echo "⏳ Waiting for API server asyncdelete..."
    wait_for_pods "app.kubernetes.io/name=clearml,app.kubernetes.io/component=asyncdelete" 180
    
    echo "🎉 ClearML deployment completed!"
    echo ""
    check_deployment_status
}

# Function to test the deployment
test_deployment() {
    echo "🧪 Testing ClearML deployment..."
    
    # Find API server pod
    local api_pod=$(oc get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=clearml" --field-selector=status.phase=Running -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
    
    if [ -n "$api_pod" ]; then
        echo "📋 Testing API server endpoint..."
        oc exec "$api_pod" -n "$NAMESPACE" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8008/debug.ping 2>/dev/null || echo "API server still initializing..."
    else
        echo "⚠️  No running API server pod found"
    fi
}

# Function to get access information
get_access_info() {
    echo "🌐 ClearML Access Information:"
    echo "=============================="
    
    # Get webserver service
    local webserver_svc=$(oc get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=clearml,app.kubernetes.io/component=webserver" -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
    
    if [ -n "$webserver_svc" ]; then
        echo "🔗 To access ClearML UI:"
        echo "   oc port-forward svc/$webserver_svc 8080:80 -n $NAMESPACE"
        echo "   Then open: http://localhost:8080"
    else
        echo "⚠️  Webserver service not found"
    fi
    
    echo ""
    echo "📋 Useful commands:"
    echo "   Check status: oc get pods -n $NAMESPACE"
    echo "   View logs: oc logs -f deployment/clearml-apiserver -n $NAMESPACE"
    echo "   Debug: oc describe pod <pod-name> -n $NAMESPACE"
}

# Main execution
case "${1:-deploy}" in
    "deploy")
        deploy_clearml
        ;;
    "test")
        test_deployment
        ;;
    "status")
        check_deployment_status
        ;;
    "info")
        get_access_info
        ;;
    "all")
        deploy_clearml
        test_deployment
        get_access_info
        ;;
    *)
        echo "Usage: $0 {deploy|test|status|info|all}"
        echo ""
        echo "Commands:"
        echo "  deploy  - Deploy ClearML to OpenShift"
        echo "  test    - Test the deployment"
        echo "  status  - Check deployment status"
        echo "  info    - Get access information"
        echo "  all     - Run deploy, test, and info"
        exit 1
        ;;
esac 