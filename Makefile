# Skóre — common dev tasks. Run from the project root.
# `make` or `make help` shows the list.

.DEFAULT_GOAL := help

APK_DEBUG := build/app/outputs/flutter-apk/app-debug.apk

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

.PHONY: clean
clean: ## Drop build/ and .dart_tool/
	flutter clean
