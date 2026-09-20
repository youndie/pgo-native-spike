# One gate, and whatever CI this repository eventually gets runs exactly this target.
#
# A local check set that differs from the CI one turns "green here, red there" into the normal
# state of affairs. Whatever is not in `make check` is not a gate.

PY ?= python3

.PHONY: check gate report fix help

help:
	@echo "make check   - the gate plus the reports"
	@echo "make gate    - blocking: the backlog index and the documents"
	@echo "make report  - non-blocking: code anchors"
	@echo "make fix     - regenerate the backlog index"

check: gate report

# Blocking. A failure here means the documentation contradicts itself.
gate:
	$(PY) scripts/backlog_index.py --check
	$(PY) scripts/docs_check.py
	$(PY) scripts/coverage_map.py --check

# Non-blocking, read by a person. It stays useful only while its NOT FOUND list is empty, so the
# legitimate exceptions are written the way the checker recognises rather than left to be
# rediscovered: an address inside a toolchain distribution or inside somebody else's repository is
# written with `!/`, which is reported in its own section and never counted as rot. Sibling
# repositories are searched because most anchors here point at xyk, zavarnik and razves.
report:
	$(PY) scripts/code_anchors.py --repos ..

fix:
	$(PY) scripts/backlog_index.py
