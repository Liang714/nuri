#!/usr/bin/env python3
"""Fails when user-facing copy moralizes food or frames exercise as compensation (spec §4, design direction)."""
import json
import re
import sys

BANNED = [
    r"\bcheat(ing)?\b", r"\bguilt(y|-free)?\b", r"\bearn(ed|s)?\b", r"\bburn (it )?off\b", r"\bwork it off\b",
    r"\bskinny\b", r"\bdetox\b", r"\bcleanse\b", r"\b(good|bad|junk) foods?\b", r"\bsinful\b",
    r"\bover budget\b", r"\byou failed\b", r"\bmust exercise\b", r"\bbefore and after\b",
    "치팅", "죄책감", "보상 운동", "살 빼", "다이어트 실패", "디톡스",
]
PATTERNS = [re.compile(p, re.IGNORECASE) for p in BANNED]


def _texts(entry):
    for loc in entry.get("localizations", {}).values():
        unit = loc.get("stringUnit")
        if unit:
            yield unit.get("value", "")
        for variation in loc.get("variations", {}).values():
            for case in variation.values():
                yield case.get("stringUnit", {}).get("value", "")


def scan(path):
    with open(path, encoding="utf-8") as f:
        catalog = json.load(f)
    findings = []
    for key, entry in catalog.get("strings", {}).items():
        for text in [key, *_texts(entry)]:
            for pattern in PATTERNS:
                if pattern.search(text):
                    findings.append((key, text, pattern.pattern))
    return findings


def main(argv):
    paths = argv[1:] or ["ios/App/Localizable.xcstrings"]
    findings = [f for p in paths for f in scan(p)]
    for key, text, pattern in findings:
        print(f"banned copy ({pattern}): key={key!r} text={text!r}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
