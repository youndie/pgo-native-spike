# One gate, and whatever CI this repository eventually gets runs exactly this target.
#
# A local check set that differs from the CI one turns "green here, red there" into the normal
# state of affairs. Whatever is not in `make check` is not a gate.

PY ?= python3

.PHONY: check gate controls report fix help

help:
	@echo "make check     - the gate plus the reports"
	@echo "make gate      - blocking: the backlog index, the documents, the readers' controls"
	@echo "make controls  - blocking: every reader that decides a number, on known inputs"
	@echo "make report    - non-blocking: code anchors"
	@echo "make fix       - regenerate the backlog index"

check: gate report

# Blocking. A failure here means the documentation contradicts itself.
gate: controls
	$(PY) scripts/backlog_index.py --check
	$(PY) scripts/docs_check.py
	$(PY) scripts/coverage_map.py --check

# The freeze, and every reader whose output became a number in the results document, run against
# inputs whose answer is known. These existed before they were wired in here, which is its own lesson: a
# control that nothing runs is indistinguishable from one that does not exist, and both of these
# had already caught a defect in the reader they guard.
controls:
	$(PY) scripts/brief_freeze.py
	$(PY) scripts/brief_freeze.py --control
	$(PY) scripts/attribution_control.py
	$(PY) scripts/profile_applied.py --control

# Non-blocking, read by a person. It stays useful only while its NOT FOUND list is empty, so the
# legitimate exceptions are written the way the checker recognises rather than left to be
# rediscovered: an address inside a toolchain distribution or inside somebody else's repository is
# written with `!/`, which is reported in its own section and never counted as rot. Sibling
# repositories are searched because most anchors here point at xyk, zavarnik and razves.
report:
	$(PY) scripts/code_anchors.py --repos ..

fix:
	$(PY) scripts/backlog_index.py
