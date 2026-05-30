#!/usr/bin/env python3
"""Benchmark local English -> Dutch/French fallback translation candidates."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


SOURCE_CASES = [
    {
        "id": "deck",
        "text": "Please send the presentation deck to the client before lunch. The current draft needs polishing, but do not change any numbers.",
    },
    {
        "id": "circle-back",
        "text": "The meeting ran longer than expected because the supplier kept circling back to the same issue.",
    },
    {
        "id": "duck-out",
        "text": "I'm going to duck out early today, but I'll review the contract tonight.",
    },
    {
        "id": "redlines",
        "text": "Please follow up with the legal team and make sure the tracked edits are still visible before we send the agreement.",
    },
    {
        "id": "table-it",
        "text": "Let's table that issue until next week so we can focus on the launch plan today.",
    },
]

TARGETS = {
    "nl": "nld_Latn",
    "fr": "fra_Latn",
}

TARGET_NAMES = {
    "nl": "Dutch",
    "fr": "French",
}


@dataclass(frozen=True)
class Candidate:
    id: str
    kind: str
    model: str
    path: Path


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def download_snapshot(model_id: str, output_dir: Path, allow_patterns: list[str] | None = None) -> Path:
    from huggingface_hub import snapshot_download

    output_dir.mkdir(parents=True, exist_ok=True)
    return Path(
        snapshot_download(
            model_id,
            local_dir=str(output_dir),
            allow_patterns=allow_patterns,
        )
    )


def convert_nllb(model_id: str, output_dir: Path, quantization: str = "int8") -> Path:
    if (output_dir / "model.bin").exists():
        return output_dir

    output_dir.mkdir(parents=True, exist_ok=True)
    run(
        [
            sys.executable,
            "-m",
            "ctranslate2.converters.transformers",
            "--model",
            model_id,
            "--quantization",
            quantization,
            "--copy_files",
            "sentencepiece.bpe.model",
            "tokenizer_config.json",
            "special_tokens_map.json",
            "--output_dir",
            str(output_dir),
            "--force",
        ]
    )
    return output_dir


def benchmark_nllb_ct2(candidate: Candidate) -> list[dict[str, object]]:
    import ctranslate2
    from transformers import AutoTokenizer

    tokenizer = AutoTokenizer.from_pretrained(str(candidate.path), src_lang="eng_Latn")
    translator = ctranslate2.Translator(str(candidate.path), device="cpu")
    rows: list[dict[str, object]] = []

    for target_code, target_lang in TARGETS.items():
        tokenizer.src_lang = "eng_Latn"
        target_prefix = [target_lang]
        for source_case in SOURCE_CASES:
            started = time.perf_counter()
            source_tokens = tokenizer.convert_ids_to_tokens(tokenizer.encode(source_case["text"]))
            result = translator.translate_batch(
                [source_tokens],
                target_prefix=[target_prefix],
                beam_size=4,
                max_decoding_length=256,
            )[0]
            tokens = result.hypotheses[0]
            if tokens and tokens[0] == target_lang:
                tokens = tokens[1:]
            output = tokenizer.decode(tokenizer.convert_tokens_to_ids(tokens), skip_special_tokens=True)
            rows.append(
                {
                    "candidate": candidate.id,
                    "kind": candidate.kind,
                    "target": target_code,
                    "case": source_case["id"],
                    "elapsedMs": int((time.perf_counter() - started) * 1000),
                    "source": source_case["text"],
                    "translation": output,
                }
            )
    return rows


def benchmark_madlad_transformers(candidate: Candidate) -> list[dict[str, object]]:
    import torch
    from transformers import T5ForConditionalGeneration, T5Tokenizer

    tokenizer = T5Tokenizer.from_pretrained(str(candidate.path))
    model = T5ForConditionalGeneration.from_pretrained(str(candidate.path), torch_dtype=torch.float32)
    model.eval()

    rows: list[dict[str, object]] = []
    target_tags = {"nl": "<2nl>", "fr": "<2fr>"}
    for target_code, tag in target_tags.items():
        for source_case in SOURCE_CASES:
            started = time.perf_counter()
            prompt = f"{tag} {source_case['text']}"
            inputs = tokenizer(prompt, return_tensors="pt")
            with torch.inference_mode():
                generated = model.generate(
                    **inputs,
                    max_new_tokens=256,
                    num_beams=4,
                    do_sample=False,
                )
            output = tokenizer.decode(generated[0], skip_special_tokens=True)
            rows.append(
                {
                    "candidate": candidate.id,
                    "kind": candidate.kind,
                    "target": target_code,
                    "case": source_case["id"],
                    "elapsedMs": int((time.perf_counter() - started) * 1000),
                    "source": source_case["text"],
                    "translation": output,
                }
            )
    return rows


def normalize_english_source(text: str) -> str:
    replacements = [
        (r"\bcurrent version is rough\b", "current draft needs polishing"),
        (r"\bclean up the wording\b", "polish the wording"),
        (r"\bwithout changing the numbers\b", "without changing any numbers"),
        (r"\bpresentation deck\b", "presentation"),
        (r"\bslide deck\b", "presentation"),
        (r"\bdeck\b", "presentation"),
        (r"\bvendor\b", "supplier"),
        (r"\bcall ran long\b", "meeting ran longer than expected"),
        (r"\bredlines\b", "tracked edits"),
        (r"\blegal(?!\s+team\b)\b", "the legal team"),
    ]
    output = text
    for pattern, replacement in replacements:
        output = re.sub(pattern, replacement, output, flags=re.IGNORECASE)
    return output


def clean_translated_output(text: str, target_code: str) -> str:
    replacements: list[tuple[str, str]]
    if target_code == "nl":
        replacements = [
            (r"\bpresentatiekaart\b", "presentatie"),
            (r"\bverkoper\b", "leverancier"),
            (r"\bde oproep\b", "het gesprek"),
            (r"\brode lijnen\b", "wijzigingen"),
            (r"\bworden gevolgd\b", "bijgehouden"),
            (r"\bbijgewerkte versies\b", "bijgehouden wijzigingen"),
            (r"\baangebrachte wijzigingen\b", "bijgehouden wijzigingen"),
            (r"\bde\s+lancingsplanning\b", "het lanceringsplan"),
            (r"\bde\s+lanceringsplanning\b", "het lanceringsplan"),
            (r"\blancingsplanning\b", "lanceringsplan"),
            (r"\blanceringsplanning\b", "lanceringsplan"),
            (r"\blancering\b", "lancering"),
        ]
    elif target_code == "fr":
        replacements = [
            (r"\bjeu de cartes\b", "présentation"),
            (r"\blivret de présentation\b", "présentation"),
            (r"\bvendeur\b", "fournisseur"),
            (r"\blignes rouges\b", "modifications suivies"),
            (r"\blangage\b", "formulation"),
            (r"\bjeu de présentation\b", "présentation"),
        ]
    else:
        return text

    output = text
    for pattern, replacement in replacements:
        output = re.sub(pattern, replacement, output, flags=re.IGNORECASE)
    return output


def load_translate_gemma_helpers():
    helper_path = Path(__file__).resolve().parents[1] / "translation" / "translate_gemma_mlx.py"
    spec = importlib.util.spec_from_file_location("translate_gemma_mlx", helper_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load {helper_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def benchmark_translategemma_mlx(candidate: Candidate) -> list[dict[str, object]]:
    from mlx_lm import generate, load

    helper = load_translate_gemma_helpers()
    model, tokenizer = load(str(candidate.path))
    rows: list[dict[str, object]] = []

    for target_code in sorted(TARGET_NAMES):
        for source_case in SOURCE_CASES:
            source = normalize_english_source(source_case["text"])
            started = time.perf_counter()
            prompt = helper.build_prompt(source, "en", target_code)
            generated = generate(
                model,
                tokenizer,
                prompt=prompt,
                max_tokens=320,
                verbose=False,
            )
            raw_output = helper.clean_output(generated)
            output = clean_translated_output(raw_output, target_code)
            rows.append(
                {
                    "candidate": candidate.id,
                    "kind": candidate.kind,
                    "target": target_code,
                    "case": source_case["id"],
                    "elapsedMs": int((time.perf_counter() - started) * 1000),
                    "source": source_case["text"],
                    "normalizedSource": source,
                    "rawTranslation": raw_output,
                    "translation": output,
                }
            )
    return rows


def write_rows(rows: list[dict[str, object]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--work-dir", default="/tmp/duckwhisperer-fallback-benchmark")
    parser.add_argument("--output", default="/tmp/duckwhisperer-fallback-benchmark/results.jsonl")
    parser.add_argument(
        "--candidate",
        action="append",
        choices=["nllb600-ct2-int8", "nllb13b-ct2-int8", "madlad3b", "translategemma-mlx"],
        required=True,
    )
    parser.add_argument("--model-dir", help="Local model directory for candidates that have already been downloaded.")
    args = parser.parse_args()

    work_dir = Path(args.work_dir)
    rows: list[dict[str, object]] = []

    for candidate_id in args.candidate:
        if candidate_id == "nllb600-ct2-int8":
            path = convert_nllb(
                "facebook/nllb-200-distilled-600M",
                work_dir / "facebook__nllb-200-distilled-600M-ct2-int8",
            )
            rows.extend(benchmark_nllb_ct2(Candidate(candidate_id, "ctranslate2", "facebook/nllb-200-distilled-600M", path)))
        elif candidate_id == "nllb13b-ct2-int8":
            path = convert_nllb(
                "facebook/nllb-200-distilled-1.3B",
                work_dir / "facebook__nllb-200-distilled-1.3B-ct2-int8",
            )
            rows.extend(benchmark_nllb_ct2(Candidate(candidate_id, "ctranslate2", "facebook/nllb-200-distilled-1.3B", path)))
        elif candidate_id == "madlad3b":
            path = download_snapshot("google/madlad400-3b-mt", work_dir / "google__madlad400-3b-mt")
            rows.extend(benchmark_madlad_transformers(Candidate(candidate_id, "transformers", "google/madlad400-3b-mt", path)))
        elif candidate_id == "translategemma-mlx":
            if args.model_dir:
                path = Path(args.model_dir)
            else:
                path = download_snapshot(
                    "mlx-community/translategemma-4b-it-4bit_immersive-translate",
                    work_dir / "mlx-community__translategemma-4b-it-4bit_immersive-translate",
                )
            rows.extend(
                benchmark_translategemma_mlx(
                    Candidate(
                        candidate_id,
                        "mlx-lm",
                        "mlx-community/translategemma-4b-it-4bit_immersive-translate",
                        path,
                    )
                )
            )

    write_rows(rows, Path(args.output))
    print(f"wrote {len(rows)} rows to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
