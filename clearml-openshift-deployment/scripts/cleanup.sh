#!/bin/bash
set -e

# ClearML OpenShift Cleanup Script
# This script removes ClearML deployment and associated resources

NAMESPACE="${NAMESPACE:-clearml}"
RELEASE_NAME="${RELEASE_NAME:-clearml}"

echo "🧹 ClearML OpenShift Cleanup Script"
echo "===================================="
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo ""

# Function to confirm cleanup
confirm_cleanup() {
    echo "⚠️  WARNING: This will delete the entire ClearML deployment and all data!"
    echo "   Namespace: $NAMESPACE"
    echo "   Release: $RELEASE_NAME"
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo "❌ Cleanup cancelled"
        exit 0
    fi
}

# Function to cleanup Helm release
cleanup_helm() {
    echo "🗑️  Removing Helm release..."
    
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
        echo "✅ Helm release removed"
    else
        echo "ℹ️  No Helm release found"
    fi
}

# Function to cleanup remaining resources
cleanup_resources() {
    echo "🗑️  Cleaning up remaining resources..."
    
    # Remove ConfigMaps
    oc delete configmap -l "app.kubernetes.io/instance=$RELEASE_NAME" -n "$NAMESPACE" --ignore-not-found=true
    
    # Remove secrets (if any were created)
    oc delete secret -l "app.kubernetes.io/instance=$RELEASE_NAME" -n "$NAMESPACE" --ignore-not-found=true
    
    # Remove PVCs (be careful with this)
    if [ "${FORCE_DELETE_PVCS:-false}" = "true" ]; then
        echo "⚠️  Force deleting PVCs..."
        oc delete pvc -l "app.kubernetes.io/instance=$RELEASE_NAME" -n "$NAMESPACE" --ignore-not-found=true
    else
        echo "ℹ️  Skipping PVC deletion (set FORCE_DELETE_PVCS=true to delete)"
    fi
    
    echo "✅ Resources cleaned up"
}

# Function to cleanup namespace
cleanup_namespace() {
    if [ "${DELETE_NAMESPACE:-false}" = "true" ]; then
        echo "🗑️  Deleting namespace..."
        oc delete namespace "$NAMESPACE" --ignore-not-found=true
        echo "✅ Namespace deleted"
    else
        echo "ℹ️  Keeping namespace (set DELETE_NAMESPACE=true to delete)"
    fi
}

# Function to verify cleanup
verify_cleanup() {
    echo "🔍 Verifying cleanup..."
    
    local pods=$(oc get pods -n "$NAMESPACE" 2>/dev/null | grep -E "(clearml|elasticsearch|mongodb|redis)" | wc -l || echo "0")
    
    if [ "$pods" -eq 0 ]; then
        echo "✅ Cleanup completed successfully"
    else
        echo "⚠️  Some resources may still be terminating"
        echo "   Run: oc get pods -n $NAMESPACE"
    fi
}

# Main cleanup function
cleanup_clearml() {
    confirm_cleanup
    cleanup_helm
    cleanup_resources
    cleanup_namespace
    verify_cleanup
}

# Function to show cleanup status
show_cleanup_status() {
    echo "📊 Current resources in namespace '$NAMESPACE':"
    echo ""
    
    echo "Pods:"
    oc get pods -n "$NAMESPACE" 2>/dev/null || echo "  No pods found or namespace doesn't exist"
    
    echo ""
    echo "Services:"
    oc get svc -n "$NAMESPACE" 2>/dev/null || echo "  No services found or namespace doesn't exist"
    
    echo ""
    echo "PVCs:"
    oc get pvc -n "$NAMESPACE" 2>/dev/null || echo "  No PVCs found or namespace doesn't exist"
}

# Main execution
case "${1:-cleanup}" in
    "cleanup")
        cleanup_clearml
        ;;
    "status")
        show_cleanup_status
        ;;
    "force")
        export FORCE_DELETE_PVCS=true
        export DELETE_NAMESPACE=true
        cleanup_clearml
        ;;
    *)
        echo "Usage: $0 {cleanup|status|force}"
        echo ""
        echo "Commands:"
        echo "  cleanup  - Remove ClearML deployment (interactive)"
        echo "  status   - Show current resources"
        echo "  force    - Force removal including PVCs and namespace"
        echo ""
        echo "Environment variables:"
        echo "  NAMESPACE           - Target namespace (default: clearml)"
        echo "  RELEASE_NAME        - Helm release name (default: clearml)"
        echo "  DELETE_NAMESPACE    - Delete namespace (default: false)"
        echo "  FORCE_DELETE_PVCS   - Delete PVCs (default: false)"
        exit 1
        ;;
esac 