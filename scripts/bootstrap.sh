#!/bin/bash
# scripts/bootstrap.sh
# One-shot script to spin up the full secure-k8s-platform locally
# Usage: ./scripts/bootstrap.sh

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()     { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()    { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
header() { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════${NC}"; }

# ── Prerequisite Check ────────────────────────────────────────────────────────
header "🔍 Checking Prerequisites"

REQUIRED_TOOLS=("docker" "kind" "kubectl" "helm" "trivy")
MISSING=()

for tool in "${REQUIRED_TOOLS[@]}"; do
  if command -v "$tool" &>/dev/null; then
    ok "$tool found: $(command -v $tool)"
  else
    MISSING+=("$tool")
    warn "$tool NOT found"
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  die "Missing tools: ${MISSING[*]}\nRun: ./scripts/install-deps.sh"
fi

# ── Cluster Creation ──────────────────────────────────────────────────────────
header "🏗️  Creating kind Cluster"

if kind get clusters | grep -q "secure-k8s"; then
  warn "Cluster 'secure-k8s' already exists. Deleting and recreating..."
  kind delete cluster --name secure-k8s
fi

kind create cluster --config infra/kind-config.yaml --wait 120s
ok "Cluster created"

export KUBECONFIG="$(pwd)/kubeconfig.yaml"
kind get kubeconfig --name secure-k8s > "$KUBECONFIG"
ok "kubeconfig written to ./kubeconfig.yaml (gitignored)"

# ── Install CNI: Calico ───────────────────────────────────────────────────────
header "🌐 Installing Calico CNI (for NetworkPolicies)"

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
log "Waiting for Calico pods to be ready..."
kubectl rollout status daemonset/calico-node -n kube-system --timeout=120s
ok "Calico installed"

# ── Install cert-manager ──────────────────────────────────────────────────────
header "🔏 Installing cert-manager"

helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true \
  --wait --timeout 120s
ok "cert-manager installed"

# ── Install Kyverno ───────────────────────────────────────────────────────────
header "🛡️  Installing Kyverno (Policy Engine)"

helm repo add kyverno https://kyverno.github.io/kyverno/ --force-update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --set admissionController.replicas=1 \
  --set backgroundController.enabled=true \
  --set reportsController.enabled=true \
  --wait --timeout 120s
ok "Kyverno installed"

# ── Install Falco ─────────────────────────────────────────────────────────────
header "🦅 Installing Falco (Runtime Security)"

helm repo add falcosecurity https://falcosecurity.github.io/charts --force-update
helm upgrade --install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --wait --timeout 120s
ok "Falco installed"

# ── Install Vault ─────────────────────────────────────────────────────────────
header "🔐 Installing HashiCorp Vault (Dev Mode)"

helm repo add hashicorp https://helm.releases.hashicorp.com --force-update
helm upgrade --install vault hashicorp/vault \
  --namespace vault --create-namespace \
  --set server.dev.enabled=true \
  --set server.dev.devRootToken="root" \
  --set injector.enabled=true \
  --wait --timeout 120s
ok "Vault installed (dev mode — configure prod mode before real use)"

# ── Install Monitoring Stack ───────────────────────────────────────────────────
header "📊 Installing Prometheus + Grafana + Loki"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update
helm repo update

# kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f monitoring/prometheus/values.yaml \
  --wait --timeout 180s

# Loki for log aggregation
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true \
  --wait --timeout 120s

ok "Monitoring stack installed"

# ── Label Nodes ───────────────────────────────────────────────────────────────
header "🏷️  Labeling Nodes"

WORKERS=($(kubectl get nodes --no-headers | grep worker | awk '{print $1}'))
kubectl label node "${WORKERS[0]}" node-role=app --overwrite
kubectl label node "${WORKERS[1]}" node-role=monitoring --overwrite
kubectl label node "${WORKERS[2]}" node-role=security --overwrite
ok "Nodes labeled"

# ── Apply RBAC & Namespaces ───────────────────────────────────────────────────
header "🔒 Applying RBAC & Namespaces"

kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/rbac/
ok "RBAC applied"

# ── Apply OPA Policies ────────────────────────────────────────────────────────
header "📋 Applying OPA Constraint Templates"

kubectl apply -f k8s/policies/
ok "Kyverno policies applied"

# ── Summary ───────────────────────────────────────────────────────────────────
header "✅ Bootstrap Complete!"
echo ""
echo -e "  ${GREEN}Cluster:${NC}     secure-k8s (kind)"
echo -e "  ${GREEN}App:${NC}         http://localhost:8080"
echo -e "  ${GREEN}Grafana:${NC}     http://localhost:3000  (admin/prom-operator)"
echo -e "  ${GREEN}Prometheus:${NC}  http://localhost:9090"
echo -e "  ${GREEN}Vault UI:${NC}    kubectl port-forward svc/vault 8200:8200 -n vault"
echo ""
echo -e "  ${CYAN}Next:${NC} Run ./scripts/deploy-app.sh to deploy the sample app"
echo ""
