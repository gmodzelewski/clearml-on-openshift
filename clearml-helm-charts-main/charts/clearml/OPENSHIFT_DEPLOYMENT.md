# ClearML OpenShift Deployment Guide
## Running with Default 'restricted' SCC (No Special Permissions Required)

This guide shows how to deploy ClearML on OpenShift using only the default `restricted` Security Context Constraint, without requiring `anyuid`, `privileged`, or any special permissions.

## Prerequisites

- OpenShift cluster access with project creation permissions
- `oc` CLI installed and configured
- `helm` CLI installed
- External Elasticsearch service (since embedded Elasticsearch requires privileged access)

## Pre-Deployment: Elasticsearch Setup

Since ClearML requires Elasticsearch and the embedded version needs privileged access, you have several options:

### Option 1: Use Managed Elasticsearch Service
- AWS OpenSearch Service
- Elastic Cloud
- Google Cloud Elasticsearch

### Option 2: Deploy Elasticsearch in Separate Privileged Namespace
If your cluster allows privileged workloads in specific namespaces:

```bash
# Create a separate namespace for Elasticsearch
oc new-project elasticsearch

# Deploy Elasticsearch with privileged access (if allowed)
# Use official Elastic Helm charts or OpenShift Elasticsearch Operator
```

### Option 3: Use OpenSearch Alternative
OpenSearch has better OpenShift compatibility:

```bash
# Deploy OpenSearch using community charts
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm install opensearch opensearch/opensearch --namespace opensearch --create-namespace
```

## ClearML Deployment Steps

### 1. Create OpenShift Project
```bash
oc new-project clearml
```

### 2. Update Elasticsearch Connection
Edit `values-openshift.yaml` and update the Elasticsearch connection string:

```yaml
externalServices:
  elasticsearchConnectionString: "[{\"host\":\"your-actual-elasticsearch-host\",\"port\":9200}]"
```

### 3. Deploy ClearML
```bash
# Deploy using the OpenShift-specific values
helm install clearml ./clearml-helm-charts-main/charts/clearml/ \
  --namespace clearml \
  --values ./clearml-helm-charts-main/charts/clearml/values-openshift.yaml
```

### 4. Expose Services via Routes
```bash
# Create OpenShift Routes for external access
oc expose svc clearml-apiserver
oc expose svc clearml-webserver  
oc expose svc clearml-fileserver
```

### 5. Get Access URLs
```bash
# Get the URLs for accessing ClearML
echo "ClearML Web UI: https://$(oc get route clearml-webserver -o jsonpath='{.spec.host}')"
echo "ClearML API: https://$(oc get route clearml-apiserver -o jsonpath='{.spec.host}')"
echo "ClearML Files: https://$(oc get route clearml-fileserver -o jsonpath='{.spec.host}')"
```

## Verification

### Check Pod Status
```bash
oc get pods -n clearml
```

All pods should be running without any security violations.

### Check Security Context Compliance
```bash
# Verify no privileged containers
oc get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}'

# Check that containers run with non-root users
oc describe pods -l app.kubernetes.io/name=clearml
```

### Test ClearML Functionality
1. Access the Web UI using the route URL
2. Create a test project
3. Verify API connectivity

## Security Features

This deployment configuration ensures:

- ✅ **No privileged containers**: All containers run with `runAsNonRoot: true`
- ✅ **No special SCCs required**: Uses only the default `restricted` SCC
- ✅ **Dropped capabilities**: All containers drop ALL capabilities
- ✅ **Read-only root filesystems** where possible
- ✅ **Random UID assignment**: OpenShift assigns random UIDs automatically
- ✅ **Proper fsGroup settings**: Ensures file permissions work correctly

## Troubleshooting

### Common Issues

#### 1. fsGroup Security Constraint Violations

**Error:** `pods "clearml-apiserver-xxx" is forbidden: unable to validate against any security context constraint: [provider "restricted-v2": .spec.securityContext.fsGroup: Invalid value: []int64{1000}: 1000 is not an allowed group`

**Solution:** Remove all explicit `fsGroup` settings from the Helm values. OpenShift's `restricted-v2` SCC automatically assigns appropriate group IDs based on the namespace's UID range.

```bash
# Verify no explicit fsGroup settings exist in your values:
grep -r "fsGroup:" ./values*.yaml

# If found, remove them or set them to {} or null
```

#### 2. Elasticsearch Connection Issues
```bash
# Check if ClearML can connect to Elasticsearch
oc logs deployment/clearml-apiserver | grep -i elastic
```

#### 3. Permission Issues
```bash
# Check security context violations
oc get events --field-selector type=Warning | grep -i security

# Use the verification script
./verify-clearml-security.sh
```

#### 4. Storage Issues
```bash
# Check PVC status
oc get pvc -n clearml
```

### Verification Script

Use the provided verification script to check your deployment:

```bash
./verify-clearml-security.sh
```

This script will:
- Check pod status and security contexts
- Identify which SCC is being used
- Report any security violations
- Provide troubleshooting information for failed pods

## Alternative Configurations

### Using External MongoDB and Redis
If you prefer to use external databases:

```yaml
mongodb:
  enabled: false
redis:
  enabled: false

externalServices:
  mongodbConnectionStringAuth: "mongodb://external-mongo:27017/auth"
  mongodbConnectionStringBackend: "mongodb://external-mongo:27017/backend"
  redisHost: "external-redis-host"
  redisPort: 6379
```

### Custom Storage Classes
```yaml
mongodb:
  persistence:
    storageClass: "your-storage-class"
redis:
  master:
    persistence:
      storageClass: "your-storage-class"
fileserver:
  storage:
    storageClass: "your-storage-class"
```

## Conclusion

This configuration allows ClearML to run in the most restrictive OpenShift environments while maintaining full functionality. The key trade-off is requiring external Elasticsearch, but this actually provides better scalability and security separation in production environments. 