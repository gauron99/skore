# Skóre — common dev tasks. Run from the project root.
# `make` or `make help` shows the list.

.DEFAULT_GOAL := help

APK_DEBUG := build/app/outputs/flutter-apk/app-debug.apk
SHOTS_BIN := build/linux/x64/debug/bundle/skore
SHOTS_VENV := .tools/shots-venv

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-7s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: run
run: ## Run on Linux desktop
	flutter run -d linux

.PHONY: test
test: ## Run unit + widget tests
	flutter test

.PHONY: apk
apk: ## Build debug APK (needs JDK 17 + Android SDK)
	flutter build apk --debug
	@echo "APK: $(APK_DEBUG)"

.PHONY: shots
shots: $(SHOTS_BIN) $(SHOTS_VENV)/.installed ## Named UI screenshots (Linux, needs DISPLAY)
	$(SHOTS_VENV)/bin/python scripts/ui_shots.py $(if $(ONLY),--only $(ONLY),)

LIB_DART := $(shell find lib -name '*.dart' 2>/dev/null)

$(SHOTS_BIN): $(LIB_DART)
	flutter build linux --debug

$(SHOTS_VENV)/.installed: scripts/ui_shots_requirements.txt
	python3 -m venv $(SHOTS_VENV)
	$(SHOTS_VENV)/bin/pip install -r scripts/ui_shots_requirements.txt
	touch $(SHOTS_VENV)/.installed

.PHONY: clean
clean: ## Drop build/ and .dart_tool/
	flutter clean
