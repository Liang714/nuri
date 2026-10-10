#!/usr/bin/env python3
"""Prints the UDID of an iPhone simulator whose iOS runtime matches the installed SDK.

Usage: xcrun simctl list devices available -j | python3 scripts/pick_simulator.py "$(xcrun --sdk iphonesimulator --show-sdk-version)"

Prefers the runtime equal to the SDK's major.minor (an exact match builds and runs the same OS the app was built
against); otherwise the newest iOS runtime older than the SDK. Exits 1 with a message when no iPhone qualifies.
"""
import json
import re
import sys

RUNTIME = re.compile(r"\.SimRuntime\.iOS-(\d+)-(\d+)$")
PREFERRED = re.compile(r"^iPhone \d+( Pro)?$")


def version_of(text):
    parts = [int(p) for p in text.split(".")[:2]]
    return tuple((parts + [0, 0])[:2])


def pick(devices_by_runtime, sdk):
    """Returns (udid, runtime_version), or None. `devices_by_runtime` is the "devices" object of simctl's JSON."""
    candidates = {}
    for runtime, devices in devices_by_runtime.items():
        match = RUNTIME.search(runtime)
        if not match:
            continue
        version = (int(match.group(1)), int(match.group(2)))
        iphones = [d for d in devices if d.get("isAvailable", True) and d["name"].startswith("iPhone")]
        if iphones and version <= sdk:
            iphones.sort(key=lambda d: not PREFERRED.match(d["name"]))  # stable: plain "iPhone NN" first
            candidates[version] = iphones[0]["udid"]
    if not candidates:
        return None
    best = sdk if sdk in candidates else max(candidates)
    return candidates[best], best


def main(argv):
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    sdk = version_of(argv[1])
    found = pick(json.load(sys.stdin)["devices"], sdk)
    if found is None:
        print(f"No iPhone simulator with an iOS runtime up to {sdk[0]}.{sdk[1]} (the installed SDK)", file=sys.stderr)
        return 1
    udid, version = found
    print(f"Using iOS {version[0]}.{version[1]} simulator {udid} (SDK {sdk[0]}.{sdk[1]})", file=sys.stderr)
    print(udid)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
