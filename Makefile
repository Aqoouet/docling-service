.PHONY: help pull up up-local

help:
	@echo "Server (pull prebuilt image, no build on host):"
	@echo "  export DOCLING_SERVICE_IMAGE=ghcr.io/YOUR_USER/docling-service:latest"
	@echo "  make pull up"
	@echo ""
	@echo "Local (build Dockerfile on this machine):"
	@echo "  make up-local"

pull:
	docker compose pull

up:
	docker compose up -d

up-local:
	docker compose up -d --build
