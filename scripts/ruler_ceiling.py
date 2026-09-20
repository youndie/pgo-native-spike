#!/usr/bin/env python3
"""One row of the generator-ceiling probe: the offered rate against what came back.

The ceiling is not a property of the subject. It is asked first because an arm read off a
saturated generator is a measurement of the generator, and `dropped_iterations` is the open-model
executor admitting it could not keep up.
"""
import re
import sys

rate, log = sys.argv[1], sys.argv[2]
text = open(log, encoding="utf-8", errors="replace").read()


def grab(pat, default="?"):
    m = re.search(pat, text)
    return m.group(1) if m else default


print(",".join([
    rate,
    grab(r"http_reqs[.\s]*:\s*\d+\s+([0-9.]+)/s"),
    grab(r"p\(50\)=([0-9.]+[a-zµ]*)"),
    grab(r"p\(99\)=([0-9.]+[a-zµ]*)"),
    grab(r"dropped_iterations[.\s]*:\s*(\d+)", "0"),
    grab(r"http_req_failed[.\s]*:\s*([0-9.]+%)"),
]))
