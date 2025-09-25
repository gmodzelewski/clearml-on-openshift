# ClearML OpenShift Deployment

This repository contains a comprehensive, production-ready deployment solution for ClearML on OpenShift with enterprise security compliance.

## 🎯 Overview

This deployment solution addresses the challenges of running ClearML on OpenShift with the `restricted-v2` Security Context Constraint (SCC), providing:

- ✅ **Full OpenShift Security Compliance** (restricted-v2 SCC)
- ✅ **SSL Certificate Handling** for self-signed Elasticsearch certificates
- ✅ **Volume Permission Management** for read-only root filesystems
- ✅ **Cache File Permission Solutions** for non-root containers
- ✅ **Production-Ready Configuration** with proper resource management

## 📁 Repository Structure

```
clearml-openshift-deployment/
├── scripts/                          # Consolidated shell scripts
│   ├── ssl-bypass-startup.sh        # SSL certificate bypass solution
│   ├── cache-permission-fix.sh       # Cache permission handling
│   └── deploy-clearml.sh            # Main deployment script
├── templates/                        # Helm templates
│   ├── ssl-bypass-configmap.yaml    # SSL bypass ConfigMap template
│   ├── apiserver-deployment-patch.yaml # API server deployment patches
│   └── values-openshift-template.yaml # Values configuration template
├── config/                          # Configuration files
│   └── values-openshift.yaml       # OpenShift-specific values
└── README.md                       # This documentation
```

## 🚀 Quick Start

### Prerequisites

- OpenShift 4.x cluster with admin access
- Helm 3.x installed
- `oc` CLI configured and logged in
- ClearML Helm charts (included in parent directory)

### Basic Deployment

1. **Clone and prepare:**
   ```bash
   cd clearml-openshift-deployment
   chmod +x scripts/*.sh
   ```

2. **Deploy ClearML:**
   ```bash
   ./scripts/deploy-clearml.sh deploy
   ```

3. **Check status:**
   ```bash
   ./scripts/deploy-clearml.sh status
   ```

4. **Get access information:**
   ```bash
   ./scripts/deploy-clearml.sh info
   ```

### Complete Deployment with Testing

```bash
./scripts/deploy-clearml.sh all
```

## 🔧 Configuration

### OpenShift-Specific Settings

The `config/values-openshift.yaml` file contains all OpenShift-specific configurations:

```yaml
# Security Context Constraints compliance
podSecurityContext:
  runAsNonRoot: true
containerSecurityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  capabilities:
    drop: [ALL]

# SSL Bypass for self-signed certificates
sslBypass:
  enabled: true

# Volume configurations for writable directories
volumes:
  - name: apiserver-logs
    emptyDir: {}
  - name: writable-cache
    emptyDir: {}
```

### Environment Variables

Key environment variables for OpenShift compatibility:

```yaml
env:
  # SSL Certificate bypass
  PYTHONHTTPSVERIFY: "0"
  CLEARML__HOSTS__ELASTIC__VERIFY_CERTS: "false"
  
  # Elasticsearch connections
  CLEARML__HOSTS__ELASTIC__WORKERS__HOSTS: "[{\"host\":\"clearml-elasticsearch-es-http.clearml.svc.cluster.local\",\"port\":9200,\"scheme\":\"https\",\"use_ssl\":true}]"
  
  # Authentication
  ELASTIC_USER: "elastic"
  ELASTIC_PASSWORD: "your-password-here"
```

## 🛠️ Components

### 1. SSL Bypass Solution (`ssl-bypass-startup.sh`)

Handles self-signed SSL certificates from Elasticsearch:

- Disables SSL verification at Python SSL context level
- Suppresses urllib3 SSL warnings
- Configures environment variables for SSL bypass
- Maintains secure connections while bypassing certificate verification

### 2. Cache Permission Fix (`cache-permission-fix.sh`)

Resolves cache file permission issues in restricted environments:

- Creates writable cache directories in `/tmp`
- Sets proper file permissions for non-root users
- Works with OpenShift's random UID assignment

### 3. Deployment Automation (`deploy-clearml.sh`)

Comprehensive deployment script with:

- Automated namespace creation
- Helm deployment with proper wait conditions
- Infrastructure readiness checks
- Service endpoint testing
- Access information display

### 4. Helm Templates

#### SSL Bypass ConfigMap (`ssl-bypass-configmap.yaml`)
```yaml
{{- if .Values.clearml.sslBypass.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "clearml.fullname" . }}-ssl-bypass-startup
data:
  startup.sh: |
    # SSL bypass script content
{{- end }}
```

#### API Server Deployment Patch (`apiserver-deployment-patch.yaml`)
```yaml
{{- if .Values.clearml.apiserver.openshift.enabled }}
spec:
  template:
    spec:
      initContainers:
        - name: fix-cache-permissions
          # Cache permission fix
      containers:
        - name: clearml-apiserver
          command: ["/ssl-bypass-startup/startup.sh"]
          # SSL bypass configuration
{{- end }}
```

## 🔍 Troubleshooting

### Common Issues

1. **SSL Certificate Errors**
   ```
   [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: self-signed certificate
   ```
   **Solution:** Ensure SSL bypass is enabled in `values-openshift.yaml`

2. **Cache Permission Denied**
   ```
   PermissionError: [Errno 13] Permission denied: '/opt/clearml/apiserver/schema/services/_cache.json'
   ```
   **Solution:** Init container handles this automatically

3. **Pod Security Violations**
   ```
   Pod failed to create: violates restricted-v2 security context constraint
   ```
   **Solution:** Use the provided OpenShift security contexts

### Debugging Commands

```bash
# Check pod status
oc get pods -n clearml

# View API server logs
oc logs -f deployment/clearml-apiserver -n clearml

# Debug pod issues
oc describe pod <pod-name> -n clearml

# Test API endpoint
oc exec <pod-name> -n clearml -- curl -s http://localhost:8008/debug.ping
```

## 📊 Architecture

### Security Architecture

```
┌─────────────────────────────────────────┐
│             OpenShift Cluster           │
│  ┌─────────────────────────────────────┐ │
│  │        restricted-v2 SCC            │ │
│  │  ┌─────────────────────────────────┐ │ │
│  │  │         ClearML Pods            │ │ │
│  │  │  • Non-root user execution      │ │ │
│  │  │  • No privileged escalation     │ │ │
│  │  │  • Capabilities dropped         │ │ │
│  │  │  • EmptyDir volumes for writes  │ │ │
│  │  └─────────────────────────────────┘ │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Network Architecture

```
┌──────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   WebServer  │◄───┤   API Server    │◄───┤   Elasticsearch  │
│  (ClusterIP) │    │   (ClusterIP)   │    │    (HTTPS)       │
└──────────────┘    └─────────────────┘    └──────────────────┘
                           │                         │
                           ▼                         ▼
                    ┌─────────────┐         ┌──────────────┐
                    │   MongoDB   │         │    Redis     │
                    │ (ClusterIP) │         │ (ClusterIP)  │
                    └─────────────┘         └──────────────┘
```

## 🏷️ Labels and Selectors

Standard Kubernetes labels are used throughout:

```yaml
labels:
  app.kubernetes.io/name: clearml
  app.kubernetes.io/instance: clearml
  app.kubernetes.io/component: apiserver
  app.kubernetes.io/part-of: clearml
  app.kubernetes.io/managed-by: Helm
```

## 🔒 Security Considerations

### Security Context Constraints

All pods comply with OpenShift's `restricted-v2` SCC:
- Run as non-root user
- No privilege escalation
- All capabilities dropped
- Read-only root filesystem where possible

### SSL/TLS Configuration

- Self-signed certificate handling
- Secure SSL bypass for internal communications
- Environment-based certificate verification control

### Secret Management

- Elasticsearch credentials via environment variables
- ConfigMap-based script distribution
- Proper RBAC configuration (when applicable)

## 📈 Production Considerations

### Resource Requirements

Minimum recommended resources:
```yaml
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

### Persistence

- Use persistent volumes for production data
- Configure backup strategies for MongoDB and Elasticsearch
- Consider storage classes for different performance tiers

### Monitoring

- Pod resource utilization
- Application-level metrics
- SSL certificate expiration monitoring

### High Availability

- Multiple replicas for stateless components
- Persistent storage for stateful components
- Load balancing configuration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes in OpenShift environment
4. Submit pull request with detailed description

## 📝 License

This project is provided as-is for educational and enterprise deployment purposes.

## 🆘 Support

For issues related to:
- **OpenShift deployment**: Check troubleshooting section
- **ClearML functionality**: Refer to official ClearML documentation
- **Security contexts**: Consult OpenShift SCC documentation

---

**🎉 Successfully deployed ClearML on OpenShift with enterprise security compliance!** 