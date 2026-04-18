.PHONY: help pull up

help:
	@echo "Pull the official Docling Serve image and start:"
	@echo "  make pull up"
	@echo ""
	@echo "Optional overrides:"
	@echo "  export DOCLING_SERVICE_IMAGE=quay.io/docling-project/docling-serve-cpu:latest"
	@echo "  export HOST_PORT=5001"
	@echo "  make pull up"

pull:
	docker compose pull

up:
	docker compose up -d
