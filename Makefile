.PHONY: get build-ios pub-reset format check-format init gen quick-gen test-gold delete-gold test-cov prep-ipad prep-mac


clean: 
	flutter clean
	rm -rf lib/generated 

get:
	@flutter pub get
	@echo

build-ios:
	flutter build ios

pub-reset:
	@echo Cleaning pub cache from system
	@flutter pub cache clean -f

gen:
	@echo Generating necessary dart files...
	@echo All prior generated files will be re-generated
	@dart run build_runner build --delete-conflicting-outputs
	@dart format lib/generated -l 120 

format: 
	dart fix --apply
	dart format . -l 120
	
check-format:
	dart format --output=none -l 120 --set-exit-if-changed .

test-gold:
	flutter test --update-goldens

delete-gold:
	find ./test/ -wholename '*golden*' -delete 
	find ./test/ -wholename '*failures*' -delete 