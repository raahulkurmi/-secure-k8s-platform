# 🔐 Secure Kubernetes Platform

> End-to-End DevSecOps platform built on Kubernetes with defense-in-depth security architecture.

## 🏗️ Architecture

- **Infrastructure**: kind (local) — 1 control-plane + 3 worker nodes
- **Policy Engine**: Kyverno — 10 security policies enforced at admission
- **Runtime Security**: Falco — eBPF-based threat detection
- **Networking**: Calico — zero-trust NetworkPolicies
- **Secret Management**: HashiCorp Vault
- **Observability**: Prometheus + Grafana + Loki
- **App**: 3-tier Todo app (React + Node.js + PostgreSQL)

## 🚀 Quick Start
```bash
# 1. Create cluster
cd infra && kind create cluster --config kind-config.yaml --wait 120s

# 2. Bootstrap everything
cd .. && ./scripts/bootstrap.sh

# 3. Deploy app
./scripts/deploy-app.sh
```

## 📁 Structure
```
├── app/          # Frontend, Backend, Database
├── infra/        # kind cluster config
├── k8s/          # Kubernetes manifests + Kyverno policies
├── scripts/      # Bootstrap and deploy scripts
└── monitoring/   # Prometheus + Grafana configs
```

## 🔒 Security Layers

| Layer | Tool | What it does |
|---|---|---|
| Admission Control | Kyverno | Blocks non-compliant pods |
| Runtime Security | Falco | Detects threats at runtime |
| Networking | Calico | Zero-trust between pods |
| Secrets | Vault | No plaintext secrets |
| Observability | Prometheus + Grafana | Full visibility |
