# Skóre — common dev tasks. Run from the project root.
# `make` or `make help` shows the list.

.DEFAULT_GOAL := help

APK_DEBUG := build/app/outputs/flutter-apk/app-debug.apk
SHOTS_BIN := build/linux/x64/debug/bundle/skore
SHOTS_VENV := .tools/shots-venv

# Flutter: .tools/flutter (git-ignored; an SDK or a symlink to one) wins over
# flutter on PATH. Override with make FLUTTER=/path/to/bin/flutter. Resolved
# only when a recipe needs it, so make help works without an SDK.
FLUTTER ?= $(or $(wildcard .tools/flutter/bin/flutter),$(shell command -v flutter 2>/dev/null),$(error Flutter not found. Put an SDK (or a symlink to one) at .tools/flutter, or put flutter on PATH))

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: run
run: ## Run on Linux desktop
	$(FLUTTER) run -d linux

.PHONY: test
test: ## Run unit + widget tests
	$(FLUTTER) test

.PHONY: apk
apk: ## Build debug APK (needs JDK 17 + Android SDK)
	$(FLUTTER) build apk --debug
	@echo "APK: $(APK_DEBUG)"

.PHONY: shots
shots: $(SHOTS_BIN) $(SHOTS_VENV)/.installed ## Named UI screenshots (Linux, needs DISPLAY)
	$(SHOTS_VENV)/bin/python scripts/ui_shots.py $(if $(ONLY),--only $(ONLY),)

LIB_DART := $(shell find lib -name '*.dart' 2>/dev/null)

$(SHOTS_BIN): $(LIB_DART)
	$(FLUTTER) build linux --debug

$(SHOTS_VENV)/.installed: scripts/ui_shots_requirements.txt
	python3 -m venv $(SHOTS_VENV)
	$(SHOTS_VENV)/bin/pip install -r scripts/ui_shots_requirements.txt
	touch $(SHOTS_VENV)/.installed

.PHONY: ship
ship: ## Push to main. REV= names the change; default is @, else @-, if non-empty and described. DRY_RUN=1 checks
	@FLUTTER="$(FLUTTER)" REV="$(REV)" DRY_RUN="$(DRY_RUN)" scripts/ship.sh

.PHONY: clean
clean: ## Drop build/ and .dart_tool/
	$(FLUTTER) clean
