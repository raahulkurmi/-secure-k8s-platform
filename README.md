# 🔐 Secure Kubernetes Platform

> A production-grade, end-to-end DevSecOps platform built on Kubernetes with defense-in-depth security architecture — policy enforcement at admission, runtime threat detection, zero-trust networking, and full GitOps deployment.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Security Layers](#security-layers)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Application](#application)
- [CI/CD Pipeline](#cicd-pipeline)
- [Kyverno Policies](#kyverno-policies)
- [Network Policies](#network-policies)
- [GitOps with ArgoCD](#gitops-with-argocd)
- [Quick Start](#quick-start)
- [Key Debugging Stories](#key-debugging-stories)
- [Production Considerations](#production-considerations)

---

## Overview

Most Kubernetes projects stop at "deploy an app." This project builds security into every layer of the stack — from the moment code is pushed to the moment a pod runs on the cluster.

**What this project demonstrates:**

- **Admission control** — Kyverno policies block any pod that violates security standards before it ever runs
- **Runtime security** — Falco monitors syscalls and detects threats at the kernel level using eBPF
- **Zero-trust networking** — Calico NetworkPolicies enforce explicit allow-lists between every service
- **GitOps** — ArgoCD ensures the cluster always reflects what's in Git, nothing more
- **Secure CI/CD** — GitHub Actions pipeline with Dockerfile linting, SAST scanning, image scanning, and Kyverno policy validation as gates before any image is pushed

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Developer Workstation                           │
│                                                                         │
│   git push ──────────────────────────────────────────────────────────► │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        GitHub Actions (CI)                              │
│                                                                         │
│  ① Lint & Validate      ② Security Scan       ③ Build & Scan Images    │
│  ┌───────────────┐      ┌───────────────┐      ┌───────────────────┐   │
│  │ hadolint      │ ───► │ Trivy (SAST)  │ ───► │ Build image       │   │
│  │ kubeconform   │      │ Kyverno CLI   │      │ Trivy (image)     │   │
│  └───────────────┘      └───────────────┘      │ Push → GHCR       │   │
│                                                 └───────────────────┘   │
│                                                          │               │
│                                          ④ Update Manifests             │
│                                          sed image tag → git commit      │
└──────────────────────────────────────────────────────────┬──────────────┘
                                                           │
                                                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        ArgoCD (CD / GitOps)                             │
│                                                                         │
│   Watches Git repo ──► Detects tag change ──► Auto-syncs to cluster    │
└──────────────────────────────────────────────────────────┬──────────────┘
                                                           │
                                                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     Kind Cluster (1 control-plane + 3 workers)          │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Admission Layer (Kyverno — 10 policies enforced)                │  │
│  │  Every pod is validated before it runs                           │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────────┐    │
│  │   ingress-     │    │   namespace:   │    │   namespace:       │    │
│  │   nginx        │───►│   app          │    │   argocd           │    │
│  │                │    │                │    │                    │    │
│  │  todo.local    │    │  frontend (2x) │    │  argocd-server     │    │
│  │  argocd.local  │    │  backend  (2x) │    │  app-controller    │    │
│  └────────────────┘    │  postgres (1x) │    │  repo-server       │    │
│                        └────────────────┘    └────────────────────┘    │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Runtime Layer (Falco — eBPF syscall monitoring)                 │  │
│  │  Detects privilege escalation, shell spawns, file tampering      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Network Layer (Calico — Zero-trust NetworkPolicies)             │  │
│  │  Default deny all · Explicit allow-lists only                    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Security Layers

| Layer | Tool | What It Does |
|---|---|---|
| **Admission Control** | Kyverno | Validates every pod spec at creation time — blocks non-compliant workloads before they run |
| **Runtime Security** | Falco | Monitors kernel-level syscalls using eBPF — detects privilege escalation, reverse shells, file tampering |
| **Network Security** | Kubernetes NetworkPolicy | Zero-trust — default deny all, explicit allow-lists per hop using namespaceSelector + podSelector AND conditions |
| **Image Security** | Trivy | Scans Dockerfiles and container images for HIGH/CRITICAL CVEs in the CI pipeline |
| **Network Policies** | Kubernetes NetworkPolicy (apiVersion: networking.k8s.io/v1) | Single entry point into the cluster via hostPort binding — routes by hostname/path |
| **GitOps** | ArgoCD | Git is the single source of truth — drift detection and automatic reconciliation |
| **Dockerfile Linting** | hadolint | Enforces Dockerfile best practices (no root, no latest, proper layer ordering) |
| **Manifest Validation** | kubeconform | Validates Kubernetes manifests against the official API schema in CI |

---

## Tech Stack

| Category | Technology |
|---|---|
| **Container Orchestration** | Kubernetes (kind — 1 control-plane + 3 workers) |
| **CNI** | Calico (enables NetworkPolicy enforcement on kind) |
| **Policy Engine** | Kyverno v1.11 |
| **Runtime Security** | Falco (eBPF / modern_ebpf driver) |
| **GitOps / CD** | ArgoCD (installed via Helm) |
| **Ingress** | ingress-nginx |
| **Ingress** | ingress-nginx |
| **Container Registry** | GitHub Container Registry (GHCR) |
| **Image Scanning** | Trivy (filesystem + image scan) |
| **Dockerfile Linting** | hadolint |
| **Manifest Validation** | kubeconform |
| **TLS / Cert Management** | cert-manager |
| **Frontend** | React + Vite + Nginx |
| **Backend** | Node.js + Express |
| **Database** | PostgreSQL |

---

## Repository Structure

```
secure-k8s-platform/
│
├── app/
│   ├── frontend/                   # React (Vite) — served via Nginx
│   │   ├── Dockerfile              # Multi-stage, non-root, read-only FS
│   │   ├── src/App.jsx
│   │   └── package.json
│   │
│   └── backend/                    # Node.js + Express REST API
│       ├── Dockerfile              # Multi-stage, non-root, read-only FS
│       ├── src/index.js            # Helmet, CORS, rate-limiting, pg pool
│       └── package.json
│
├── infra/
│   ├── kind-config.yaml            # Cluster: 1 control-plane + 3 workers
│   │                               # Port mappings: 80, 443 for ingress
│   └── audit-policy.yaml           # CIS-compliant API server audit logging
│
├── k8s/
│   ├── base/
│   │   ├── kubernetes_spec.yaml    # All app deployments + services
│   │   └── ingress.yaml            # todo.local routing rules
│   │
│   ├── policies/
│   │   └── kyverno-policies.yaml   # 10 ClusterPolicies (see below)
│   │
│   └── network-policies/
│       └── network-policies.yaml   # 7 NetworkPolicies (zero-trust)
│
├── scripts/
│   ├── bootstrap.sh                # One-shot cluster setup script
│   ├── deploy-app.sh               # Build images + deploy to cluster
│   └── install-deps.sh             # Install all CLI tools (macOS/Linux)
│
└── .github/
    └── workflows/
        └── ci.yaml                 # 4-stage CI/CD pipeline
```

---

## Application

A 3-tier **Todo Application** built to demonstrate security-hardened deployments on Kubernetes.

```
browser
   │
   ▼
ingress-nginx (todo.local)
   │
   ├── /         ──► frontend (React + Nginx)  :8080
   └── /api/     ──► backend  (Node.js + Express) :3000
                         │
                         ▼
                      postgres :5432
                    (PersistentVolumeClaim)
```

**Security hardening applied to every container:**

- Multi-stage Docker builds (minimal runtime image)
- Non-root user (`uid 1001`)
- Read-only root filesystem
- Dropped ALL Linux capabilities
- Resource limits on CPU and memory
- Health and readiness probes (`/healthz`, `/readyz`)
- Rate limiting and Helmet security headers on the backend

**Access locally:**

```bash
# After cluster setup
echo "127.0.0.1 todo.local" | sudo tee -a /etc/hosts
# App is accessible at: http://todo.local
```

---

## CI/CD Pipeline

The pipeline runs on every push to `main` and every pull request. Four jobs run sequentially — each is a security gate that must pass before the next runs.

```
push to main
     │
     ▼
┌─────────────────────┐
│  ① Lint & Validate  │  hadolint (Dockerfile) + kubeconform (manifests)
└──────────┬──────────┘
           │ pass
           ▼
┌─────────────────────┐
│  ② Security Scan    │  Trivy filesystem (SAST) + Kyverno CLI policy check
└──────────┬──────────┘
           │ pass
           ▼
┌─────────────────────┐
│  ③ Build & Scan     │  Build images → Trivy image scan → Push to GHCR
│     Images          │  Tags: ghcr.io/raahulkurmi/secure-todo-{backend,frontend}:<sha>
└──────────┬──────────┘
           │ pass (main branch only)
           ▼
┌─────────────────────┐
│  ④ Update Manifests │  sed updates image tag in kubernetes_spec.yaml
│                     │  Commits change back to repo → ArgoCD picks it up
└─────────────────────┘
```

**Image tagging strategy:** Every build produces a unique, immutable tag based on the commit SHA (e.g., `a1b2c3d`). No `:latest` — pinned tags only, as enforced by Kyverno policy.

---

## Kyverno Policies

10 `ClusterPolicy` resources enforced in **Enforce** mode (blocks the request) or **Audit** mode (reports but allows). Applied at admission time — before any pod reaches a node.

| # | Policy | Mode | Reason |
|---|---|---|---|
| 01 | `disallow-privileged-containers` | Enforce | Prevents container escape to host — privileged mode gives full kernel access |
| 02 | `require-run-as-non-root` | Enforce | Root in container = root on host if escape succeeds. Requires `runAsUser ≥ 1000` |
| 03 | `disallow-latest-tag` | Enforce | `:latest` is non-reproducible and unpinned — must use immutable SHA-based tags |
| 04 | `require-resource-limits` | Enforce | Without limits a single pod can starve the entire node (DoS) |
| 05 | `disallow-host-namespaces` | Enforce | `hostPID`, `hostIPC`, `hostNetwork` break node isolation boundaries |
| 06 | `require-readonly-rootfs` | Enforce | Read-only root FS prevents attackers from persisting malware to disk |
| 07 | `disallow-host-path` | Enforce | hostPath volumes expose the node filesystem to the container |
| 08 | `disallow-capabilities` | Enforce | Drops all Linux capabilities — eliminates root-equivalent powers like `CAP_SYS_ADMIN` |
| 09 | `require-standard-labels` | Audit | Enforces governance labels (`app`, `version`, `component`) on all workloads |
| 10 | `require-pod-disruption-budget` | Audit | Flags workloads without PDBs — required for safe rolling updates in production |

**Verify policies are active:**

```bash
kubectl get clusterpolicy
# All 10 should show READY: True
```

**See live policy reports:**

```bash
kubectl get policyreport -n app
```

> 💡 **Portfolio moment:** During development, Kyverno blocked the PostgreSQL deployment because the container was running as root without a read-only filesystem. This forced a proper fix — adding `securityContext.runAsNonRoot: true`, `runAsUser: 999`, and `readOnlyRootFilesystem: true` to the manifest — exactly the kind of enforcement this tool is designed for.

---

## Network Policies

7 `NetworkPolicy` resources (enforced by Calico) implementing zero-trust networking in the `app` namespace. The model is simple: **default deny all ingress and egress for every pod**, then explicitly allow only what the application needs.

```
internet
    │
    ▼
ingress-nginx controller pod          (ingress-nginx namespace)
    │
    │  allowed by: allow-ingress-to-frontend
    │  (namespaceSelector: ingress-nginx + podSelector: controller pod only)
    ▼
frontend pods :8080                   (app namespace)
    │
    │  allowed by: allow-frontend-egress-backend (egress)
    │            + allow-frontend-to-backend     (ingress on backend)
    ▼
backend pods :3000                    (app namespace)
    │
    │  allowed by: allow-backend-egress-postgres (egress)
    │            + allow-backend-to-postgres     (ingress on postgres)
    ▼
postgres pods :5432                   (app namespace)

postgres → anything              ❌ default deny (no egress policy)
backend  → internet              ❌ default deny (only DNS + postgres egress allowed)
frontend → postgres              ❌ blocked (cannot skip backend layer)
any other pod → backend/postgres ❌ blocked (label selector is specific)
```

**All 7 policies — what each one does and why:**

| # | Policy Name | Type | Direction | Detail |
|---|---|---|---|---|
| 1 | `default-deny-all` | Ingress + Egress | All pods | Baseline — blocks everything. Every other policy is an exception to this. |
| 2 | `allow-ingress-to-frontend` | Ingress | → frontend:8080 | Source must match BOTH `namespaceSelector: ingress-nginx` AND `podSelector: app.kubernetes.io/component=controller` — only the ingress-nginx controller pod, not any other pod in that namespace |
| 3 | `allow-frontend-to-backend` | Ingress | → backend:3000 | `podSelector: app=frontend` — only frontend pods can reach backend. Frontend must have the `app: frontend` label, which is set in the deployment. Policy lives in the backend's namespace. |
| 4 | `allow-backend-to-postgres` | Ingress | → postgres:5432 | `podSelector: app=postgres` — only backend pods allowed. Postgres cannot be reached by frontend or any other pod directly. |
| 5 | `allow-backend-egress-dns` | Egress | backend → kube-dns:53 | Backend needs DNS to resolve `postgres-svc`. Without this, even allowed connections fail because service names can't resolve. |
| 6 | `allow-frontend-egress-backend` | Egress | frontend → backend:3000 | Egress side of policy #3. Both ingress (on backend) and egress (on frontend) must be allowed for traffic to flow. |
| 7 | `allow-backend-egress-postgres` | Egress | backend → postgres:5432 | Egress side of policy #4. Backend can only talk outbound to postgres — nothing else. |

**Key concept learned during implementation:** NetworkPolicy is a namespaced resource. A policy protecting `backend` must be created in the `app` namespace — it cannot protect pods in other namespaces. The `from` block (source selector) is separate — it can reference any namespace using `namespaceSelector`. Same indentation = AND condition (both namespace AND pod label must match). Separate list items = OR condition.

**Verify all policies:**

```bash
kubectl get networkpolicy -n app
# Expected: 7 policies listed

# Test the traffic flow is working end-to-end after applying policies
curl http://todo.local/api/todos
```

---

## GitOps with ArgoCD

ArgoCD is installed via Helm and watches the `k8s/base/` directory of this repository. When the CI pipeline commits an updated image tag, ArgoCD detects the change and automatically syncs the cluster.

```
Developer pushes code
         │
         ▼
GitHub Actions builds + pushes image to GHCR
         │
         ▼
Pipeline commits updated image tag to k8s/base/kubernetes_spec.yaml
         │
         ▼
ArgoCD polls Git (every 3 minutes or via webhook)
         │
         ▼
ArgoCD detects diff between Git state and cluster state
         │
         ▼
ArgoCD syncs — cluster is updated automatically
```

**Git is the single source of truth.** No `kubectl apply` in production. Any manual change to the cluster will be overwritten by ArgoCD on the next sync.

**Access the ArgoCD UI locally:**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080
# Username: admin
# Password: kubectl get secret argocd-initial-admin-secret -n argocd \
#             -o jsonpath="{.data.password}" | base64 -d
```

---

## Quick Start

### Prerequisites

```bash
# Install required tools
./scripts/install-deps.sh

# Required: docker, kind, kubectl, helm, kyverno CLI
```

### 1. Create the cluster

```bash
cd infra
kind create cluster --config kind-config.yaml --wait 120s
cd ..
```

### 2. Bootstrap security tools

```bash
# Installs: Calico, cert-manager, Kyverno, Falco
./scripts/bootstrap.sh
```

### 3. Deploy the application

```bash
# Builds images, loads into kind, applies manifests
./scripts/deploy-app.sh
```

### 4. Install ingress-nginx

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "127.0.0.1 todo.local" | sudo tee -a /etc/hosts
kubectl apply -f k8s/base/ingress.yaml
```

### 5. Install ArgoCD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=ClusterIP \
  --wait --timeout 180s
```

### 6. Verify everything

```bash
kubectl get nodes
kubectl get pods -n kube-system     # Calico
kubectl get pods -n cert-manager
kubectl get pods -n kyverno
kubectl get pods -n falco
kubectl get pods -n ingress-nginx
kubectl get pods -n argocd
kubectl get pods -n app
kubectl get clusterpolicy           # All 10 Kyverno policies
kubectl get networkpolicy -n app    # All 7 network policies
```

### 7. Access the app

```bash
# Todo app
open http://todo.local

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
open https://localhost:8080

# API
curl http://todo.local/api/todos
```

---

## Key Debugging Stories

Real problems encountered and solved during this build — each one taught something concrete.

**Kyverno blocked our own PostgreSQL deployment**
The deploy script failed with `admission webhook denied the request`. Kyverno was enforcing `require-readonly-rootfs` and `require-run-as-non-root` — and PostgreSQL needs to write to its data directory. Fix: added `securityContext` with `runAsUser: 999`, `readOnlyRootFilesystem: true`, and an `emptyDir` volume for the data directory. This is Kyverno working exactly as intended — it forced a proper fix.

**ingress-nginx needed port 80 mapped in Kind**
The initial cluster had only `30080 → 8888` in the kind-config. Adding ingress-nginx and creating Ingress objects didn't work — the controller couldn't bind to port 80. Fix: recreated the cluster with `containerPort: 80 → hostPort: 80` in `kind-config.yaml` and the `ingress-ready=true` node label on control-plane.

**GitHub Actions SARIF duplicate upload error**
Running Trivy scans for both frontend and backend images in the same job triggered `only one run per tool/category is allowed`. Fix: added unique `category` values per upload step (`trivy-frontend`, `trivy-backend`, `trivy-fs`). Later removed SARIF uploads entirely in favour of table format output to simplify the pipeline.

**ArgoCD Helm install failed with existing ClusterRoles**
A previous `kubectl apply` install of ArgoCD left behind ClusterRoles and CRDs that Helm couldn't adopt. Fix: manually deleted the orphaned CRDs (`applications.argoproj.io`, `applicationsets.argoproj.io`, `appprojects.argoproj.io`) and ClusterRoles before retrying the Helm install.

**GitHub Actions `git push` failed with 403**
The `update-manifests` job couldn't commit back to the repo. Fix: enabled **Read and write permissions** for `GITHUB_TOKEN` in repo Settings → Actions → General → Workflow permissions, and added `permissions: contents: write` to the job definition.

---

## Production Considerations

This project runs locally on kind. Moving to production (EKS/GKE/AKS) would involve:

| Area | Local (this project) | Production |
|---|---|---|
| **Cluster** | kind (local) | EKS / GKE / AKS via Terraform |
| **Ingress** | ingress-nginx + hostPort | Istio Gateway + Cloud LoadBalancer |
| **TLS** | cert-manager (self-signed) | cert-manager + Let's Encrypt |
| **Secrets** | Kubernetes Secrets | HashiCorp Vault + External Secrets Operator |
| **Registry** | GHCR | ECR / GAR / ACR |
| **Observability** | — | Prometheus + Grafana + Loki |
| **Falco output** | stdout | Falcosidekick → Slack / PagerDuty |
| **ArgoCD HA** | Single replica | HA mode with Redis |
