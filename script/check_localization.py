#!/usr/bin/env python3
"""Validate native localization tables without third-party dependencies."""
from pathlib import Path
import json
import re
import subprocess

root = Path(__file__).resolve().parent.parent
tables = {}
for language in ("en", "vi"):
    path = root / "Sources/FanCore/Resources" / (language + ".lproj") / "Localizable.strings"
    tables[language] = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)]))
assert tables["en"].keys() == tables["vi"].keys(), "Localization keys differ"
placeholder = re.compile(r"%(?:\d+\$)?(?:\.[0-9]+)?[@dfsu]")
for key, value in tables["en"].items():
    assert placeholder.findall(value) == placeholder.findall(tables["vi"][key]), key
for path in (root / "Sources").rglob("*.swift"):
    for key in re.findall(r'L10n\.[tf]\(\s*"([^"\n]+)"\s*[,)]', path.read_text()):
        assert key in tables["en"], (str(path), key)
print(f"VI/EN: {len(tables['en'])} matching keys and format placeholders")
