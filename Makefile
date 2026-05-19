OPEN_CMD := open

GFSH_SITE_A = docker exec site-a-server gfsh -e "connect --locator=site-a-locator[10335] --jmx-manager=site-a-locator[1099]"
GFSH_SITE_B = docker exec site-b-server gfsh -e "connect --locator=site-b-locator[10335] --jmx-manager=site-b-locator[1099]"

.PHONY: start
start: ## Start all containers
	@docker compose up -d --remove-orphans

.PHONY: stop
stop: ## Stop all containers
	@docker compose down --remove-orphans

.PHONY: restart
restart: stop start ## Restart all containers

.PHONY: status
status: ## View status of services
	@docker compose ps --all --format "{{.Service}}|{{.Status}}" | column -t -s '|'

.PHONY: all-logs
all-logs: ## Attach to the firehose of logs
	@docker compose logs -f

.PHONY: logs
logs: ## View logs for a specific service (usage: make logs s=site-a-server)
	@docker compose logs -f $(s)

# ── GemFire Queries ──────────────────────────────────────────────

.PHONY: count-a
count-a: ## Count entries in Site A /Orders region
	@$(GFSH_SITE_A) -e "query --query='SELECT count(*) FROM /Orders'"

.PHONY: count-b
count-b: ## Count entries in Site B /Orders region
	@$(GFSH_SITE_B) -e "query --query='SELECT count(*) FROM /Orders'"

.PHONY: count
count: ## Count entries on both sites
	@echo "=== Site A ===" && \
	$(GFSH_SITE_A) -e "query --query='SELECT count(*) FROM /Orders'" 2>&1 | grep -A2 "^Rows\|^---\|^ " ; \
	echo "=== Site B ===" && \
	$(GFSH_SITE_B) -e "query --query='SELECT count(*) FROM /Orders'" 2>&1 | grep -A2 "^Rows\|^---\|^ "

.PHONY: query-a
query-a: ## Query all orders on Site A
	@$(GFSH_SITE_A) -e "query --query='SELECT * FROM /Orders'"

.PHONY: query-b
query-b: ## Query all orders on Site B
	@$(GFSH_SITE_B) -e "query --query='SELECT * FROM /Orders'"

.PHONY: gateways
gateways: ## Show gateway sender/receiver status
	@echo "=== Site A (Sender) ===" && \
	$(GFSH_SITE_A) -e "list gateways" 2>&1 | tail -8 ; \
	echo "=== Site B (Receiver) ===" && \
	$(GFSH_SITE_B) -e "list gateways" 2>&1 | tail -8

.PHONY: members-a
members-a: ## List Site A cluster members
	@$(GFSH_SITE_A) -e "list members"

.PHONY: members-b
members-b: ## List Site B cluster members
	@$(GFSH_SITE_B) -e "list members"

.PHONY: gfsh-a
gfsh-a: ## Open interactive gfsh shell connected to Site A
	@docker exec -it site-a-server gfsh

.PHONY: gfsh-b
gfsh-b: ## Open interactive gfsh shell connected to Site B
	@docker exec -it site-b-server gfsh

# ── WAN Link Controls (via Toxiproxy) ───────────────────────────

.PHONY: kill-wan
kill-wan: ## Kill the WAN link (disable both proxies)
	@echo "Killing WAN link..." && \
	curl -s -X POST -H "Content-Type: application/json" \
		-d '{"enabled":false}' \
		http://localhost:8474/proxies/wan_locator > /dev/null && \
	curl -s -X POST -H "Content-Type: application/json" \
		-d '{"enabled":false}' \
		http://localhost:8474/proxies/wan_receiver > /dev/null && \
	echo "WAN link killed (proxies disabled)"

.PHONY: restore-wan
restore-wan: ## Restore the WAN link (re-enable both proxies)
	@echo "Restoring WAN link..." && \
	curl -s -X POST -H "Content-Type: application/json" \
		-d '{"enabled":true}' \
		http://localhost:8474/proxies/wan_locator > /dev/null && \
	curl -s -X POST -H "Content-Type: application/json" \
		-d '{"enabled":true}' \
		http://localhost:8474/proxies/wan_receiver > /dev/null && \
	echo "WAN link restored (proxies enabled)"

.PHONY: slow-wan
slow-wan: ## Add 2s latency to the WAN link
	@echo "Adding 2s latency..." && \
	curl -s -X POST -H "Content-Type: application/json" \
		-d '{"name":"latency_wan_locator","type":"latency","attributes":{"latency":2000,"jitter":500}}' \
		http://localhost:8474/proxies/wan_locator/toxics > /dev/null && \
	curl -s -X POST -H "Content-Type: application/json" \
		-d '{"name":"latency_wan_receiver","type":"latency","attributes":{"latency":2000,"jitter":500}}' \
		http://localhost:8474/proxies/wan_receiver/toxics > /dev/null && \
	echo "Latency added (2000ms +/- 500ms)"

.PHONY: unslow-wan
unslow-wan: ## Remove latency from the WAN link
	@echo "Removing latency..." && \
	curl -s -X DELETE http://localhost:8474/proxies/wan_locator/toxics/latency_wan_locator > /dev/null 2>&1 ; \
	curl -s -X DELETE http://localhost:8474/proxies/wan_receiver/toxics/latency_wan_receiver > /dev/null 2>&1 ; \
	echo "Latency removed"

.PHONY: wan-status
wan-status: ## Show toxiproxy status and active toxics
	@echo "=== Proxies ===" && \
	curl -s http://localhost:8474/proxies | python3 -m json.tool 2>/dev/null || \
	curl -s http://localhost:8474/proxies ; \
	echo "\n=== wan_locator toxics ===" && \
	curl -s http://localhost:8474/proxies/wan_locator/toxics | python3 -m json.tool 2>/dev/null || \
	curl -s http://localhost:8474/proxies/wan_locator/toxics ; \
	echo "\n=== wan_receiver toxics ===" && \
	curl -s http://localhost:8474/proxies/wan_receiver/toxics | python3 -m json.tool 2>/dev/null || \
	curl -s http://localhost:8474/proxies/wan_receiver/toxics

# ── Browser ──────────────────────────────────────────────────────

.PHONY: open-ui
open-ui: ## Open the Grafana dashboard in a browser
	@$(OPEN_CMD) http://localhost:3000

.PHONY: open-controls
open-controls: ## Open the control app in a browser
	@$(OPEN_CMD) http://localhost:8080

.PHONY: open-prometheus
open-prometheus: ## Open the Prometheus UI in a browser
	@$(OPEN_CMD) http://localhost:9090

# ── Database ─────────────────────────────────────────────────────

.PHONY: wipe-db
wipe-db: ## Remove persistent data directories
	@rm -rf data/site-a data/site-b
	@echo "Wiped data/site-a and data/site-b"

.PHONY: fresh
fresh: ## Full reset: stop containers, wipe data, restart
	@docker compose down --remove-orphans
	@$(MAKE) wipe-db
	@docker compose up -d --remove-orphans

# ── Help ─────────────────────────────────────────────────────────

.DEFAULT_GOAL := help
help: ## Print help for each make target
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
