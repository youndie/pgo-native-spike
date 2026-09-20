#!/usr/bin/env python3
"""The frozen half of the pre-registration still hashes to what it did when it arrived.

A pre-registration is worth having only because its text cannot move after the numbers come in.
That guarantee used to rest on a file in the owner's `~/Downloads`: the digest was recorded in
BRIEF.md, and anybody who did not hold that file had nothing to check it against. B-14 moved the
received text into `docs/research/source-brief.md`, and this is what makes the claim checkable
from the repository alone.

    scripts/brief_freeze.py            # check
    scripts/brief_freeze.py --control  # prove the check can fail

The file is a docs-bootstrap document up to a marker line and the received bytes after it. Only
the part after the marker is hashed, so the wrapper can be edited - it is this repository's own
prose - while the frozen text cannot.
"""
import hashlib
import sys
from pathlib import Path

BRIEF = Path(__file__).resolve().parent.parent / "docs" / "research" / "source-brief.md"
MARKER = b"<!-- ---8<--- everything after this line is the received text, byte for byte ---8<--- -->\n"
# As received on 2026-09-20 and verified against the received file by B-01 while it still existed.
DIGEST = "77d8480c45cba5eae46d7f46f7006a23fe336492bb43a54f7902c87608859a77"
SIZE = 18849


def frozen_bytes(data):
    """Everything after the marker line. Read as bytes: the digest is over bytes, not over text."""
    index = data.find(MARKER)
    if index < 0:
        raise ValueError(f"no marker line in {BRIEF.name}; the frozen text cannot be located")
    if data.find(MARKER, index + 1) >= 0:
        raise ValueError("more than one marker line; which text is frozen is ambiguous")
    return data[index + len(MARKER):]


def check(data, label):
    body = frozen_bytes(data)
    digest = hashlib.sha256(body).hexdigest()
    ok = digest == DIGEST and len(body) == SIZE
    if ok:
        print(f"{label}: the brief as received is unedited - {len(body)} bytes, sha256 {digest[:16]}...")
    else:
        print(f"{label}: THE FROZEN TEXT HAS CHANGED", file=sys.stderr)
        print(f"  expected {SIZE} bytes, sha256 {DIGEST}", file=sys.stderr)
        print(f"  found    {len(body)} bytes, sha256 {digest}", file=sys.stderr)
    return ok


def control():
    """A freeze check that passes whatever it is given is the same as no freeze check."""
    data = BRIEF.read_bytes()
    body = frozen_bytes(data)
    print("control for scripts/brief_freeze.py")
    ok = True

    def case(label, mutated, want):
        nonlocal ok
        got = hashlib.sha256(frozen_bytes(mutated)).hexdigest() == DIGEST and len(frozen_bytes(mutated)) == SIZE
        status = "ok  " if got == want else "FAIL"
        if got != want:
            ok = False
        print(f"  {status} {label}: accepted={got}, want={want}")

    case("the committed file", data, True)
    # One character, in the middle of the frozen text, changing nothing a reader would notice.
    half = len(body) // 2
    flipped = body[:half] + (b"x" if body[half : half + 1] != b"x" else b"y") + body[half + 1 :]
    case("one character changed", data.replace(body, flipped), False)
    # Whitespace only: the case a tidying editor or a formatter produces.
    case("one trailing newline added", data + b"\n", False)
    # Editing the WRAPPER must stay allowed - it is this repository's prose, not the frozen text.
    case("wrapper prose edited", data.replace(b"# The frozen text", b"# The frozen text (note)"), True)
    return ok


if __name__ == "__main__":
    if "--control" in sys.argv:
        sys.exit(0 if control() else 1)
    sys.exit(0 if check(BRIEF.read_bytes(), BRIEF.name) else 1)
