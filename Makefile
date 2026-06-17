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

.PHONY: all cluster argocd deploy get-argocd lint template sync destroy help

## ── Full setup (runs steps 1 → 3 in order) ──────────────────
all: cluster argocd deploy

## ── Step 1: Create EKS cluster ───────────────────────────────
cluster:
	@bash bootstrap/01-create-cluster.sh

## ── Step 2: Install ArgoCD with LoadBalancer ─────────────────
argocd:
	@bash bootstrap/02-install-argocd.sh

## ── Step 3: Deploy paas-app (App-of-Apps) via ArgoCD ─────────
deploy:
	kubectl apply -f argocd/apps/paas-app.yaml

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

## ── Lint the app-of-apps chart ───────────────────────────────
lint:
	helm lint app-of-apps

## ── Dry-run template render (shows the 8 child Applications) ──
template:
	helm template paas app-of-apps --debug 2>&1 | head -200

## ── Force ArgoCD to hard-sync the parent app ─────────────────
sync:
	argocd app sync paas-app --force

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
	@echo "  make deploy        — Apply paas-app (App-of-Apps) to ArgoCD"
	@echo "  make all           — Run all 3 steps in order"
	@echo "  make get-argocd    — Print ArgoCD URL and password"
	@echo "  make lint          — Lint app-of-apps chart"
	@echo "  make template      — Dry-run template render (8 child apps)"
	@echo "  make sync          — Force ArgoCD sync of paas-app"
	@echo "  make destroy       — Delete EKS cluster (irreversible!)"
	@echo ""
