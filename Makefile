## ============================================================
## Platform Umbrella — Makefile
## Usage: make <target>
##
## Prerequisites: eksctl, kubectl, helm, aws CLI, argocd CLI
## ============================================================

CLUSTER_NAME ?= platform-cluster
REGION       ?= us-east-1
ARGOCD_NS    ?= argocd
GIT_REPO     ?= https://github.com/vishalliverpool/Umbrella-arogocd-deployment.git

.PHONY: all cluster argocd deploy get-argocd helm-deps lint destroy help

## ── Full setup (runs steps 1 → 3 in order) ──────────────────
all: cluster argocd deploy

## ── Step 1: Create EKS cluster ───────────────────────────────
cluster:
	@bash bootstrap/01-create-cluster.sh

## ── Step 2: Install ArgoCD with LoadBalancer ─────────────────
argocd:
	@bash bootstrap/02-install-argocd.sh

## ── Step 3: Deploy platform umbrella via ArgoCD ──────────────
deploy:
	@GIT_REPO=$(GIT_REPO) bash bootstrap/03-deploy-platform.sh

## ── Get ArgoCD credentials (run after 'make argocd') ─────────
get-argocd:
	@echo "──────────────────────────────────────────────"
	@echo "  ArgoCD URL:"
	@echo "  http://$(shell kubectl get svc argocd-server -n $(ARGOCD_NS) \
		-o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)"
	@echo ""
	@echo "  Username: admin"
	@echo "  Password: $(shell kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' 2>/dev/null | base64 --decode)"
	@echo "──────────────────────────────────────────────"

## ── Update helm dependency lock (run after editing Chart.yaml) ─
helm-deps:
	helm dependency update charts/platform-umbrella

## ── Lint the umbrella chart ──────────────────────────────────
lint:
	helm lint charts/platform-umbrella

## ── Dry-run template render ──────────────────────────────────
template:
	helm template platform charts/platform-umbrella --debug 2>&1 | head -200

## ── Force ArgoCD to hard-sync the umbrella ───────────────────
sync:
	argocd app sync platform-umbrella --force

## ── Destroy everything (cluster + all resources) ─────────────
destroy:
	@echo "⚠️  This will DELETE the EKS cluster and all resources."
	@read -p "Type cluster name to confirm [$(CLUSTER_NAME)]: " confirm; \
	[ "$$confirm" = "$(CLUSTER_NAME)" ] || (echo "Aborted." && exit 1)
	eksctl delete cluster --name $(CLUSTER_NAME) --region $(REGION) --wait

## ── Help ─────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  make cluster       — Create EKS cluster via eksctl"
	@echo "  make argocd        — Install ArgoCD (prints URL + password)"
	@echo "  make deploy        — Apply platform umbrella Application to ArgoCD"
	@echo "  make all           — Run all 3 steps in order"
	@echo "  make get-argocd    — Print ArgoCD URL and password"
	@echo "  make helm-deps     — Update Helm dependency lock file"
	@echo "  make lint          — Lint umbrella chart"
	@echo "  make template      — Dry-run template render"
	@echo "  make sync          — Force ArgoCD sync"
	@echo "  make destroy       — Delete EKS cluster (irreversible!)"
	@echo ""
