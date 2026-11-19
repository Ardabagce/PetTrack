#!/usr/bin/env python3
"""Builds src/i18n/<lang>.json from tools/translations.py (+ translations_extra.py).

Keys are the English source strings. Swift-style placeholders (%@, %lld, %1$@) are converted to
i18next placeholders {{a}}, {{b}}, … in order, so code calls t('Day {{a}} of {{b}}', { a, b }).
"""
import json, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from translations import T  # noqa: E402
try:
    from translations_extra import T as EXTRA  # noqa: E402
except ImportError:
    EXTRA = {}

LANGS = ["es", "de", "fr", "nl"]
NAMES = "abcdefghij"

def convert_key(key):
    i = 0
    def rep(_):
        nonlocal i
        name = NAMES[i]; i += 1
        return "{{" + name + "}}"
    return re.sub(r"%(?:lld|@|d)", rep, key.replace("%%", "%"))

def convert_value(value):
    i = 0
    def rep(m):
        nonlocal i
        if m.group(1):
            return "{{" + NAMES[int(m.group(1)) - 1] + "}}"
        name = NAMES[i]; i += 1
        return "{{" + name + "}}"
    return re.sub(r"%(?:(\d)\$)?(?:lld|@|d)", rep, value.replace("%%", "%"))

table = {}
for source in (T, EXTRA):
    for key, values in source.items():
        assert len(values) == 4, key
        table[convert_key(key)] = [convert_value(v) for v in values]

os.makedirs(os.path.join(ROOT, "src", "i18n"), exist_ok=True)
for idx, lang in enumerate(LANGS):
    data = {k: v[idx] for k, v in sorted(table.items())}
    with open(os.path.join(ROOT, "src", "i18n", f"{lang}.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
print(f"{len(table)} keys × {len(LANGS)} languages")
