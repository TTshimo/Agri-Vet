"""Translate AgroLens diagnosis content with an existing machine-translation model.

English is the only language anyone writes by hand:
  * assets/data/disease_knowledge_base.json   – disease content ({"en": ...} fields)
  * assets/data/disease_info.json              – Learn tab content
  * assets/i18n/en.json                        – screen text (diagnosis, Learn)

This script flattens both into keys, translates every key into each language
listed in assets/i18n/languages.json, and writes assets/i18n/<code>.json.
The app loads the file for the language chosen in Settings and falls back to
English for any missing key.

Human corrections live in assets/i18n/overrides/<code>.json (same keys) and
always win over machine output. A translation is only re-run when its English
source text changes (hashes kept in scripts/i18n_cache/), so corrections and
earlier output stay stable.

Model: Meta's NLLB-200 (facebook/nllb-200-distilled-600M by default; set
NLLB_MODEL to use a larger variant). NLLB is licensed CC-BY-NC-4.0, i.e. for
non-commercial use — swap the model before any commercial release.

Usage:
  python scripts/translate.py              # translate what's missing/changed
  python scripts/translate.py --check      # list what would be translated
  python scripts/translate.py --keys-only  # just print the English key map
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KB_PATH = ROOT / "assets/data/disease_knowledge_base.json"
INFO_PATH = ROOT / "assets/data/disease_info.json"  # the Learn tab
I18N_DIR = ROOT / "assets/i18n"
UI_EN_PATH = I18N_DIR / "en.json"
LANGS_PATH = I18N_DIR / "languages.json"
OVERRIDES_DIR = I18N_DIR / "overrides"
CACHE_DIR = ROOT / "scripts/i18n_cache"

MODEL_NAME = os.environ.get("NLLB_MODEL", "facebook/nllb-200-distilled-600M")
PLACEHOLDER = re.compile(r"\{[a-z_]+\}")


# ── English source ──────────────────────────────────────────────────────────

def kb_english(kb: dict) -> dict[str, str]:
    """Flatten every {"en": ...} field of the knowledge base into keys.

    Keys mirror DiagnosisScreen's lookups (lib/services/i18n_keys.dart):
      kb.<category>.<disease>.<field>
      kb.<category>.<disease>.rec.<level>
      kb.<category>.<disease>.q.<questionId>
      kb.<category>.<disease>.q.<questionId>.o<index>
    """
    out: dict[str, str] = {}
    for category, diseases in kb.items():
        for disease, data in diseases.items():
            base = f"kb.{category}.{disease}"
            for field, value in data.items():
                if isinstance(value, dict) and "en" in value:
                    out[f"{base}.{field}"] = str(value["en"])
            for level, value in (data.get("recommendations") or {}).items():
                if isinstance(value, dict) and "en" in value:
                    out[f"{base}.rec.{level}"] = str(value["en"])
            for q in data.get("behavioral_questions") or []:
                qkey = f"{base}.q.{q['id']}"
                out[qkey] = str(q["question"]["en"])
                for i, option in enumerate(q["options"]["en"]):
                    out[f"{qkey}.o{i}"] = str(option)
    return out


# Learn-tab fields people read (risk_level is a code, not text).
INFO_FIELDS = ("display_name", "symptoms", "affects", "spreads_by", "what_to_do", "prevention", "urgency")


def info_english(info: dict) -> dict[str, str]:
    """Learn tab content as keys: learn.<disease>.<field>."""
    return {
        f"learn.{disease}.{field}": str(data[field])
        for disease, data in info.items()
        for field in INFO_FIELDS
        if isinstance(data.get(field), str) and data[field].strip() and data[field] != "N/A"
    }


def english_strings() -> dict[str, str]:
    kb = json.loads(KB_PATH.read_text(encoding="utf-8"))
    info = json.loads(INFO_PATH.read_text(encoding="utf-8"))
    ui = json.loads(UI_EN_PATH.read_text(encoding="utf-8"))
    strings = {k: v for k, v in ui.items() if not k.startswith("_")}
    strings.update(kb_english(kb))
    strings.update(info_english(info))
    return strings


def digest(text: str) -> str:
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:12]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(dict(sorted(data.items())), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


# ── Translation ─────────────────────────────────────────────────────────────

_SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+(?=[A-Z0-9])")


class Translator:
    def __init__(self) -> None:
        import torch  # noqa: F401  (imported lazily: heavy)
        from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

        print(f"Loading {MODEL_NAME} ...", flush=True)
        self.tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, src_lang="eng_Latn")
        self.model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME)
        self.model.eval()

    def translate(self, texts: list[str], target: str, batch_size: int = 16) -> list[str]:
        """Translate texts into an NLLB language code, sentence by sentence
        (NLLB is trained on sentences and drifts on long paragraphs)."""
        import torch

        pieces: list[str] = []
        spans: list[tuple[int, int]] = []
        for text in texts:
            sentences = [s for s in _SENTENCE_SPLIT.split(text.strip()) if s] or [text]
            spans.append((len(pieces), len(pieces) + len(sentences)))
            pieces.extend(sentences)

        target_id = self.tokenizer.convert_tokens_to_ids(target)
        translated: list[str] = []
        for start in range(0, len(pieces), batch_size):
            batch = pieces[start:start + batch_size]
            inputs = self.tokenizer(batch, return_tensors="pt", padding=True, truncation=True, max_length=256)
            with torch.no_grad():
                generated = self.model.generate(
                    **inputs,
                    forced_bos_token_id=target_id,
                    max_new_tokens=256,
                    num_beams=4,
                )
            translated.extend(self.tokenizer.batch_decode(generated, skip_special_tokens=True))
            print(f"  {target}: {min(start + batch_size, len(pieces))}/{len(pieces)}", flush=True)

        return [" ".join(translated[a:b]).strip() for a, b in spans]


def protect(text: str) -> tuple[str, list[str]]:
    """Swap {placeholders} for numbered markers the model leaves alone."""
    found = PLACEHOLDER.findall(text)
    for i, ph in enumerate(found):
        text = text.replace(ph, f"[{i}]", 1)
    return text, found


def restore(text: str, found: list[str]) -> str | None:
    for i, ph in enumerate(found):
        if f"[{i}]" not in text:
            return None  # model dropped a placeholder: let the app fall back to English
        text = text.replace(f"[{i}]", ph, 1)
    return text


# ── Main ────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="report work without translating")
    parser.add_argument("--keys-only", action="store_true", help="print the English key map")
    parser.add_argument("--only", help="comma-separated language codes to process")
    args = parser.parse_args()

    english = english_strings()
    if args.keys_only:
        print(json.dumps(english, ensure_ascii=False, indent=2))
        return 0

    languages = [l for l in json.loads(LANGS_PATH.read_text(encoding="utf-8")) if l["code"] != "en"]
    if args.only:
        wanted = set(args.only.split(","))
        languages = [l for l in languages if l["code"] in wanted]

    translator = None
    for lang in languages:
        code, nllb = lang["code"], lang["nllb"]
        out_path = I18N_DIR / f"{code}.json"
        cache_path = CACHE_DIR / f"{code}.json"
        existing = load_json(out_path)
        cache = load_json(cache_path)          # key -> digest of the English it was made from
        overrides = load_json(OVERRIDES_DIR / f"{code}.json")

        todo = [
            k for k, en in english.items()
            if k not in overrides and (k not in existing or cache.get(k) != digest(en))
        ]
        print(f"{lang['name']} ({code}): {len(todo)} to translate, {len(overrides)} human overrides", flush=True)
        if args.check:
            continue

        machine = {k: v for k, v in existing.items() if k in english and k not in overrides}
        if todo:
            translator = translator or Translator()
            protected = [protect(english[k]) for k in todo]
            results = translator.translate([p[0] for p in protected], nllb)
            for key, (_, found), result in zip(todo, protected, results):
                restored = restore(result, found)
                if restored:
                    machine[key] = restored
                    cache[key] = digest(english[key])
                else:
                    machine.pop(key, None)
                    print(f"  ! {code} {key}: placeholder lost, will show English", flush=True)

        final = {**machine, **{k: v for k, v in overrides.items() if k in english}}
        cache = {k: v for k, v in cache.items() if k in machine}
        write_json(out_path, final)
        write_json(cache_path, cache)

    return 0


if __name__ == "__main__":
    sys.exit(main())
