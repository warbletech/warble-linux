# Warble Linux — developer entry points
# https://github.com/warbletech/warble-linux

.PHONY: help bake all-editions clean mock lint check test-artifacts release-check sync-bootloaders version bump-patch bump-minor bump-major

EDITION ?= 1
MOCK_ONLY ?= 0
export EDITION MOCK_ONLY

# Catch the common typo `make edition=2`, which would silently build edition 1.
ifdef edition
$(error use upper-case EDITION=$(edition), e.g. `make bake EDITION=$(edition)`)
endif

help:
	@echo "Warble Linux  $$(cat VERSION 2>/dev/null || echo '?')"
	@echo ""
	@echo "  make bake EDITION=1|2|3|4   Build one edition (default: 1)"
	@echo "  make all-editions           Build editions 1–4"
	@echo "  make mock EDITION=4         Force mock artifacts"
	@echo "  make test-artifacts         Validate out/ (size, tar, OVF, checksums)"
	@echo "  make release-check          all-editions + test-artifacts"
	@echo "  make version                Print VERSION (semver)"
	@echo "  make bump-patch|minor|major Bump VERSION file"
	@echo "  make sync-bootloaders       Refresh syslinux/grub/efiboot from archiso"
	@echo "  make clean                  Remove out/ and work dirs"
	@echo "  make lint                   Shell syntax check"
	@echo "  make check                  lint + mock bake edition 1"
	@echo ""
	@echo "Editions: 1=minimal 2=developer 3=cloud-native 4=full"
	@echo "Release:  git tag v\$$(cat VERSION) && git push origin v\$$(cat VERSION)"
	@echo "          or: gh workflow run release.yml -f bump=patch"

bake:
	@chmod +x scripts/make-and-bake.sh
	./scripts/make-and-bake.sh

all-editions:
	@chmod +x scripts/build-all-editions.sh scripts/make-and-bake.sh
	./scripts/build-all-editions.sh

mock:
	MOCK_ONLY=1 $(MAKE) bake

clean:
	rm -rf out /tmp/warble-linux-work
	@echo "cleaned out/ and /tmp/warble-linux-work"

lint:
	@bash -n scripts/make-and-bake.sh
	@bash -n scripts/build-all-editions.sh
	@bash -n scripts/push-to-gcp.sh
	@bash -n scripts/test-artifacts.sh
	@bash -n scripts/sync-bootloaders.sh
	@bash -n scripts/docker-bake.sh
	@bash -n scripts/version.sh
	@for f in profile/airootfs/usr/local/bin/*.sh profile/airootfs/etc/profile.d/*.sh; do \
	  bash -n "$$f" || exit 1; \
	done
	@echo "lint OK"

test-artifacts:
	@chmod +x scripts/test-artifacts.sh
	./scripts/test-artifacts.sh

release-check: lint
	@chmod +x scripts/build-all-editions.sh scripts/make-and-bake.sh scripts/test-artifacts.sh
	./scripts/build-all-editions.sh
	./scripts/test-artifacts.sh

check: lint
	MOCK_ONLY=1 EDITION=1 ./scripts/make-and-bake.sh
	@test -n "$$(ls out/MANIFEST-minimal-*.txt 2>/dev/null)"
	@test -n "$$(ls out/warble-linux-minimal-*.iso 2>/dev/null)"
	@test -d profile/syslinux && test -d profile/grub
	@echo "check OK (full matrix: make release-check)"

sync-bootloaders:
	@chmod +x scripts/sync-bootloaders.sh
	./scripts/sync-bootloaders.sh

version:
	@chmod +x scripts/version.sh
	@./scripts/version.sh print

bump-patch:
	@chmod +x scripts/version.sh
	@./scripts/version.sh bump patch
	@echo "VERSION is now $$(cat VERSION)"

bump-minor:
	@chmod +x scripts/version.sh
	@./scripts/version.sh bump minor
	@echo "VERSION is now $$(cat VERSION)"

bump-major:
	@chmod +x scripts/version.sh
	@./scripts/version.sh bump major
	@echo "VERSION is now $$(cat VERSION)"
