#!/usr/bin/env python3
"""Fails when user-facing copy moralizes food or frames exercise as compensation (spec §4, design direction)."""
import json
import re
import sys

BANNED = [
    # Moralizing food or framing exercise as compensation (English)
    r"\bcheat(s|ed|ing)?\b", r"\bguilt(y|-free)?\b", r"\bearn(ed|s)?\b",
    r"\bburn(s|ed|ing|t)?\s+((it|them|that)\s+)?off\b", r"\bwork(s|ed|ing)?\s+((it|that|dinner|lunch|breakfast)\s+)?off\b",
    r"\bskinny\b", r"\bdetox\b", r"\bcleanse\b", r"\b(good|bad|junk) foods?\b", r"\bsinful\b",
    r"\bover budget\b", r"\byou failed\b", r"\bmust exercise\b", r"\bbefore and after\b",
    # Food words use "Add", never "Log" (activity words use "Log")
    r"\blog\s+(your\s+)?(meals?|foods?)\b",
    # Korean, spacing-tolerant
    "치팅", "죄책감", "디톡스",
    r"보상\s*운동", r"살\s*빼", r"다이어트(에)?\s*실패", r"(나쁜|좋은)\s*음식", r"정크\s*푸드",
    r"칼로리를?\s*태", r"운동으로\s*만회",
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
        seen = set()  # one finding per key and pattern, even when the English value repeats the key
        for text in [key, *_texts(entry)]:
            for pattern in PATTERNS:
                if pattern.pattern not in seen and pattern.search(text):
                    seen.add(pattern.pattern)
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
