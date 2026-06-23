.PHONY: get build-ios pub-reset format check-format init gen quick-gen test test-gold delete-gold test-cov prep-ipad prep-mac reboot

FVM ?= fvm
FLUTTER := $(FVM) flutter
DART := $(FVM) dart
DART_FORMAT_DIRS := lib test

clean:
	$(FLUTTER) clean
	rm -rf lib/generated

get:
	@$(FLUTTER) pub get
	@echo

build-ios:
	$(FLUTTER) build ios

reboot:
	@make clean && make get && make gen && make build-ios

pub-reset:
	@echo Cleaning pub cache from system
	@$(FLUTTER) pub cache clean -f

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

test:
	$(FLUTTER) test

test-gold:
	$(FLUTTER) test --update-goldens

delete-gold:
	find ./test/ -wholename '*golden*' -delete
	find ./test/ -wholename '*failures*' -delete
