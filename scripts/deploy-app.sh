#!/bin/bash
# scripts/deploy-app.sh
# Builds images, loads into kind, deploys all manifests
# Usage: ./scripts/deploy-app.sh (run from project root)

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()     { echo -e "${GREEN}[OK]${NC}    $*"; }
header() { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; \
           echo -e "${CYAN}  $*${NC}"; \
           echo -e "${CYAN}══════════════════════════════════════${NC}"; }

# ── Build Images ──────────────────────────────────────────────────────────────
header "🐳 Building Docker Images"

docker build -t secure-todo-backend:1.0.0  app/backend/
ok "Backend image built"

docker build -t secure-todo-frontend:1.0.0 app/frontend/
ok "Frontend image built"

# ── Scan Images with Trivy ────────────────────────────────────────────────────
header "🔍 Scanning Images with Trivy"

trivy image --exit-code 0 --severity HIGH,CRITICAL secure-todo-backend:1.0.0
trivy image --exit-code 0 --severity HIGH,CRITICAL secure-todo-frontend:1.0.0
ok "Trivy scans complete"

# ── Load into kind ────────────────────────────────────────────────────────────
header "📦 Loading Images into kind Cluster"

kind load docker-image secure-todo-backend:1.0.0  --name secure-k8s
kind load docker-image secure-todo-frontend:1.0.0 --name secure-k8s
ok "Images loaded into kind"

# ── Apply Manifests ───────────────────────────────────────────────────────────
header "🚀 Deploying to Kubernetes"

kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/base/

ok "Manifests applied"

# ── Wait for Rollout ──────────────────────────────────────────────────────────
header "⏳ Waiting for Deployments"

kubectl rollout status deployment/postgres -n app --timeout=120s
kubectl rollout status deployment/backend  -n app --timeout=120s
kubectl rollout status deployment/frontend -n app --timeout=120s

ok "All deployments ready"

# ── Summary ───────────────────────────────────────────────────────────────────
header "✅ App Deployed!"
echo ""
echo -e "  ${GREEN}Frontend:${NC}  http://localhost:8888"
echo -e "  ${GREEN}Backend:${NC}   http://localhost:8888/api/todos"
echo ""
echo -e "  kubectl get pods -n app"
echo ""
