.PHONY: help check test build scan up down deploy

help:
	@echo "check: Rego tests + 10 negative fixtures + raw/Helm policy validation"
	@echo "test: backend unit tests (install app/backend/requirements.txt first)"
	@echo "build: build frontend/backend images; scan: build and scan all three images"
	@echo "up/down: start/stop the local Compose demo"
	@echo "deploy: gated deployment; supply CONTEXT=... VALUES=..."

check:
	bash scripts/check.sh

test:
	cd app/backend && python3 -m unittest discover -v

build:
	docker compose build

scan: build
	bash scripts/scan.sh docker.io/securecicd/frontend:dev docker.io/securecicd/backend:dev docker.io/library/redis:7.4-alpine

up:
	docker compose up --build -d --wait

down:
	docker compose down

deploy:
	bash scripts/deploy.sh "$(CONTEXT)" "$(VALUES)"
