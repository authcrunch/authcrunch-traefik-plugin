APP_NAME="authcrunch-traefik-plugin"
APP_VERSION:=$(shell cat VERSION | head -1)
GIT_COMMIT:=$(shell git describe --dirty --always)
GIT_BRANCH:=$(shell git rev-parse --abbrev-ref HEAD -- | head -1)
LATEST_GIT_COMMIT:=$(shell git log --format="%H" -n 1 | head -1)
BUILD_USER:=$(shell whoami)
BUILD_DATE:=$(shell date +"%Y-%m-%d")
BUILD_DIR:=$(shell pwd)
TRAEFIK_VERSION := v3.6.9
BIN_DIR := bin
TRAEFIK_BIN := $(BIN_DIR)/traefik

# Detect OS and Architecture
OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
    ARCH := amd64
endif
ifeq ($(ARCH),aarch64)
    ARCH := arm64
endif
ifeq ($(ARCH),arm64)
    ARCH := arm64
endif

all: build_info build
	@echo "$@: complete"

.PHONY: build_info
build_info:
	@echo "Version: $(APP_VERSION), Branch: $(GIT_BRANCH), Revision: $(GIT_COMMIT)"
	@echo "Build on $(BUILD_DATE) by $(BUILD_USER)"

.PHONY: build
build:
	@echo "$@: started"
	@mkdir -p ./bin/
	@echo "$@: complete"

.PHONY: test
test:
	@echo "$@: started"
	@ls -F plugins-local/src/github.com/authcrunch/$(APP_NAME)/
	@echo "$@: complete"

.PHONY: clean
clean:
	@echo "$@: started"
	@rm -rf bin/
	@echo "$@: complete"

.PHONY: dep
dep: get-traefik
	@echo "$@: started"
	@versioned || go install github.com/greenpau/versioned/cmd/versioned@latest
	@echo "$@: complete"

.PHONY: get-traefik
get-traefik:
	@echo "$@: started"
	@if [ ! -f $(TRAEFIK_BIN) ]; then \
		echo "Downloading Traefik $(TRAEFIK_VERSION) for $(OS)/$(ARCH)..."; \
		mkdir -p $(BIN_DIR); \
		curl -sL "https://github.com/traefik/traefik/releases/download/$(TRAEFIK_VERSION)/traefik_$(TRAEFIK_VERSION)_$(OS)_$(ARCH).tar.gz" -o traefik.tar.gz; \
		tar -xzf traefik.tar.gz -C $(BIN_DIR) traefik; \
		rm traefik.tar.gz; \
		chmod +x $(TRAEFIK_BIN); \
		echo "Traefik binary installed at $(TRAEFIK_BIN)"; \
	else \
		echo "Traefik binary already exists at $(TRAEFIK_BIN)"; $(TRAEFIK_BIN) version; \
	fi
	@echo "$@: complete"

.PHONY: sync-vendor
sync-vendor:
	@echo "$@: started"
	@cd plugins-local/src/github.com/authcrunch/$(APP_NAME)/ && go mod download
	@cd plugins-local/src/github.com/authcrunch/$(APP_NAME)/ && go mod vendor
	@find plugins-local/src/github.com/authcrunch/$(APP_NAME)/
	@echo "$@: complete"

.PHONY: run-local
run-local:
	@echo "$@: started"
	@$(TRAEFIK_BIN) --configFile=traefik.yml
	@echo "$@: complete"

.PHONY: release
release:
	@echo "$@: started"
	@go mod tidy;
	@go mod verify;
	@if [ $(GIT_BRANCH) != "main" ]; then echo "cannot release to non-main branch $(GIT_BRANCH)" && false; fi
	@git diff-index --quiet HEAD -- || ( echo "git directory is dirty, commit changes first" && false )
	@versioned -patch
	@echo "Patched version"
	@git add VERSION
	@git commit -m "released v`cat VERSION | head -1`"
	@git tag -a v`cat VERSION | head -1` -m "v`cat VERSION | head -1`"
	@git push
	@git push --tags
	@echo "$@: complete"
