.PHONY: clean clean-artifacts get init gen format check-format check-imports check-imports-baseline analyze verify test test-gold delete-gold test-cov cov reboot run-test-login build-ios build-ios-test-login build-ios-testflight build-mac deploy-ios redeploy-ios prep-ipad prep-mac pub-reset

FVM ?= fvm
FLUTTER := $(FVM) flutter
DART := $(FVM) dart
DART_FORMAT_DIRS := lib test

clean:
	$(FLUTTER) clean
	rm -rf lib/generated

# Free disk space from Xcode/Flutter build output (DerivedData, build/, caches,
# old device symbols). Run after a PR merges. ARGS: --dry-run, --erase-simulators,
# --old-runtimes, --all (see scripts/clean-build-artifacts.sh --help).
clean-artifacts:
	@scripts/clean-build-artifacts.sh $(ARGS)

get:
	@$(FLUTTER) --version
	@$(FLUTTER) pub get
	@echo

reboot:
	@make clean && make get && make gen && make build-ios

# Run with the email/password test login on the sign-in screen (for simulator
# and agent testing; never used for release builds). Pass a device via ARGS,
# e.g. `make run-test-login ARGS="-d 'iPhone 17 Pro'"`. See docs/DEVELOPMENT.md.
run-test-login:
	$(FLUTTER) run --dart-define=ENABLE_TEST_LOGIN=true $(ARGS)

build-ios:
	@echo "Building iOS app with Xcode: $$(xcodebuild -version | head -1)"
	$(FLUTTER) build ios

# Device build with the test login and the Developer page (never for release).
# Install it with `make deploy-ios`. See docs/DEVELOPMENT.md.
build-ios-test-login:
	@echo "Building iOS app with Xcode: $$(xcodebuild -version | head -1)"
	$(FLUTTER) build ios --dart-define=ENABLE_TEST_LOGIN=true

build-ios-testflight:
	@echo "Building iOS app with Xcode: $$(xcodebuild -version | head -1)"
	$(FLUTTER) build ipa --release

build-mac:
	@echo "Building macOS app with Xcode: $$(xcodebuild -version | head -1)"
	$(FLUTTER) build macos --no-tree-shake-icons

# Install to a connected device. Requires `brew install ios-deploy` and a prior
# `make build-ios` (expects build/ios/iphoneos/Runner.app). Pass extra flags via ARGS.
deploy-ios:
	@echo Deploying app to iOS device...
	ios-deploy -b build/ios/iphoneos/Runner.app $(ARGS)

# Uninstall from the device, then install (useful when entitlements or bundle id changed).
redeploy-ios:
	@echo Redeploying app to iOS device...
	ios-deploy -r -b build/ios/iphoneos/Runner.app $(ARGS)

pub-reset:
	@echo Cleaning pub cache from system
	@$(FLUTTER) pub cache clean -f

init:
	@echo Initializing Xplore repository...
	@make clean
	@make get
	@make gen
	@if [ ! -f assets/.env ]; then \
		echo Creating assets/.env stub...; \
		printf 'GEMINI_API_KEY=\nAPPLE_API_KEY=\nMACOS_API_KEY=\nDISABLE_REALTIME_LOCATIONS=true\nLOCATION_INTERVAL_UPDATE=\n' > assets/.env; \
	else \
		echo assets/.env already exists, skipping; \
	fi
	@echo Checking Flutter health...
	$(FLUTTER) doctor -v

gen:
	@echo Generating necessary dart files...
	@echo All prior generated files will be re-generated
	@$(DART) run build_runner build --delete-conflicting-outputs
	@$(DART) format lib/generated -l 120

format:
	$(DART) fix --apply
	$(DART) format $(DART_FORMAT_DIRS) -l 120

check-format:
	$(DART) format --output=none -l 120 --set-exit-if-changed $(DART_FORMAT_DIRS)

# Report module-boundary violations (docs/PATTERNS.md). Fails only on a violation
# that is not in scripts/check-imports-baseline.txt. ARGS: --list for every import.
check-imports:
	@scripts/check-imports.sh $(ARGS)

# Rewrite the baseline after fixing imports, so the fixed ones cannot come back.
check-imports-baseline:
	@scripts/check-imports.sh --update-baseline

analyze:
	$(FLUTTER) analyze $(DART_FORMAT_DIRS)

# Canonical agent/CI verification: codegen, formatting, module boundaries, lint,
# then tests. Run this (not ad hoc fvm commands) to verify a change.
verify: gen check-format check-imports analyze test

test:
	$(FLUTTER) test

# Refresh golden baselines. Goldens are an Apple-only artifact (text rasterises
# differently on Linux) — only run this on a macOS host.
test-gold:
	$(FLUTTER) test --update-goldens

delete-gold:
	@find ./test/ -wholename '*golden*' -delete
	@find ./test/ -wholename '*failures*' -delete
	@echo All goldens deleted.

# CI-friendly coverage: writes coverage/lcov.info (generated sources stripped).
test-cov:
	rm -rf coverage/
	$(FLUTTER) test --coverage
	@lcov --remove coverage/lcov.info 'lib/generated/*' -o coverage/lcov.info --ignore-errors unused 2>/dev/null || true
	@echo "Coverage written to coverage/lcov.info"

# Local coverage report with HTML output (requires lcov + genhtml; opens on macOS).
cov:
	rm -rf coverage/
	$(FLUTTER) test --branch-coverage
	lcov --rc branch_coverage=1 --remove ./coverage/lcov.info 'lib/generated/*' -o coverage/lcov_cleaned.info --ignore-errors inconsistent,unused
	@echo
	genhtml coverage/lcov_cleaned.info -o coverage/html --rc branch_coverage=1 --ignore-errors inconsistent
	@open coverage/html/index.html

prep-ipad:
	@make clean
	@make get
	@make gen
	@make build-ios

prep-mac:
	@make clean
	@make get
	@make gen
	@make build-mac
