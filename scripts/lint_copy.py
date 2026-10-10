#!/usr/bin/env python3
"""Fails when user-facing copy moralizes food or frames exercise as compensation (spec §4, design direction),
or when a catalog entry lacks a translated, non-empty English or Korean value."""
import json
import re
import sys

BANNED = [
    # Moralizing food or framing exercise as compensation (English)
    r"\bcheat(s|ed|ing)?\b", r"\bguilt(y|-free)?\b", r"\bearn(ed|s)?\b",
    # "off" must end the word: "works off-device" is not exercise as compensation
    r"\bburn(s|ed|ing|t)?\s+((it|them|that)\s+)?off(?![-\w])", r"\bwork(s|ed|ing)?\s+((it|that|dinner|lunch|breakfast)\s+)?off(?![-\w])",
    r"\bburn(s|ed|ing|t)?\s+\d[\d,.]*\s*(k?cals?|calories)\b",
    r"\bskinny\b", r"\bdetox\b", r"\bcleanse\b", r"\b(good|bad|junk) foods?\b", r"\bsinful\b",
    r"\bover budget\b", r"\byou failed\b", r"\bmust exercise\b", r"\bbefore[\s-]*(and|/|&)[\s-]*after\b",
    # Food words use "Add", never "Log" (activity words use "Log")
    r"\blog\s+(your\s+)?(meals?|foods?)\b",
    # Korean, spacing-tolerant
    "치팅", "죄책감", "디톡스",
    r"보상\s*운동", r"살\s*빼", r"다이어트(에)?\s*실패", r"(나쁜|좋은)\s*음식", r"정크\s*푸드",
    r"칼로리를?\s*태", r"운동으로\s*만회",
]
PATTERNS = [re.compile(p, re.IGNORECASE) for p in BANNED]


REQUIRED_LANGUAGES = ("en", "ko")


def _units(node, top=True):
    """The leaf string units of one localization: its own stringUnit, or those at the leaves of its (possibly nested)
    plural/device variations. A variation case with no text at all yields an empty unit, so it is reported."""
    variations = node.get("variations")
    if "stringUnit" in node:
        yield node["stringUnit"]
    if variations:
        for variation in variations.values():
            for case in variation.values():
                yield from _units(case, top=False)
    elif "stringUnit" not in node and not top:
        yield {}


def _texts(entry):
    for localization in entry.get("localizations", {}).values():
        for unit in _units(localization):
            yield unit.get("value", "")


def _completeness(key, entry):
    """Findings for a key whose en or ko value is missing, not 'translated', or blank.
    Entries marked "shouldTranslate": false (brand names, symbols) have nothing to translate and are skipped."""
    if entry.get("shouldTranslate") is False:
        return
    localizations = entry.get("localizations", {})
    for lang in REQUIRED_LANGUAGES:
        units = list(_units(localizations.get(lang, {})))
        if not units:
            yield (key, "", f"incomplete: missing {lang} translation")
        for unit in units:
            if unit.get("state") != "translated":
                yield (key, unit.get("value", ""), f"incomplete: {lang} state is {unit.get('state')!r}, not 'translated'")
            elif not unit.get("value", "").strip():
                yield (key, unit.get("value", ""), f"incomplete: empty {lang} value")


def scan(path):
    with open(path, encoding="utf-8") as f:
        catalog = json.load(f)
    findings = []
    for key, entry in catalog.get("strings", {}).items():
        findings.extend(_completeness(key, entry))
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
    for key, text, rule in findings:
        kind = "catalog" if rule.startswith("incomplete") else "banned copy"
        print(f"{kind} ({rule}): key={key!r} text={text!r}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
