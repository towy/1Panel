GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean

BASE_PATH := $(shell pwd)
BUILD_PATH = $(BASE_PATH)/build
WEB_PATH = $(BASE_PATH)/frontend
SERVER_PATH = $(BASE_PATH)/backend
MAIN= $(BASE_PATH)/cmd/server/main.go
ASSERT_PATH= $(BASE_PATH)/cmd/server/web/assets
APP_NAME = 1panel
VERSION = v1.10.2-lts

clean_assets:
	rm -rf $(ASSERT_PATH)
	
package:
	@bash ./package.sh

upx_bin:
	@echo "Compressing binaries with UPX..."
	@find $(BUILD_PATH) -type f -name "$(APP_NAME)-$(VERSION)-linux-*" -exec upx {} \;

build_frontend:
	cd $(WEB_PATH) && npm install && npm run build:pro

# 使用 Go 官方编译器构建 Linux 版本
build_linux_amd64:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) -trimpath -ldflags '-s -w' -o $(BUILD_PATH)/$(APP_NAME)-$(VERSION)-linux-amd64$(BINARY_SUFFIX) $(MAIN)

build_linux_arm64:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 $(GOBUILD) -trimpath -ldflags '-s -w' -o $(BUILD_PATH)/$(APP_NAME)-$(VERSION)-linux-arm64$(BINARY_SUFFIX) $(MAIN)

build_linux_armv7:
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 $(GOBUILD) -trimpath -ldflags '-s -w' -o $(BUILD_PATH)/$(APP_NAME)-$(VERSION)-linux-armv7$(BINARY_SUFFIX) $(MAIN)

build_linux_ppc64le:
	CGO_ENABLED=0 GOOS=linux GOARCH=ppc64le $(GOBUILD) -trimpath -ldflags '-s -w' -o $(BUILD_PATH)/$(APP_NAME)-$(VERSION)-linux-ppc64le$(BINARY_SUFFIX) $(MAIN)

build_linux_s390x:
	CGO_ENABLED=0 GOOS=linux GOARCH=s390x $(GOBUILD) -trimpath -ldflags '-s -w' -o $(BUILD_PATH)/$(APP_NAME)-$(VERSION)-linux-s390x$(BINARY_SUFFIX) $(MAIN)

# 使用 Go 官方编译器构建 Darwin 版本
build_backend_on_darwin:
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 $(GOBUILD) -trimpath -ldflags '-s -w'  -o $(BUILD_PATH)/$(APP_NAME) $(MAIN)

build_all: build_frontend build_linux_amd64 build_linux_arm64 build_linux_armv7 build_linux_ppc64le build_linux_s390x

bulid_local_linux: build_frontend build_linux_amd64

build_on_local: clean_assets build_frontend build_backend_on_darwin upx_bin

