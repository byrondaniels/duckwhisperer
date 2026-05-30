#!/usr/bin/env python3
"""Translate English dictation with a local TranslateGemma MLX model."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


LANGUAGE_NAMES = {
    "en": "English",
    "fr": "French",
    "nl": "Dutch",
}


def text_chunks(text: str, max_words: int = 150) -> list[str]:
    rough_parts = re.split(r"(?<=[.!?])\s+|\n+", text)
    chunks: list[str] = []
    for part in rough_parts:
        words = part.strip().split()
        while words:
            chunk_words = words[:max_words]
            chunks.append(" ".join(chunk_words))
            words = words[max_words:]
    return chunks or [text]


def build_prompt(text: str, source_code: str, target_code: str) -> str:
    source_name = LANGUAGE_NAMES[source_code]
    target_name = LANGUAGE_NAMES[target_code]
    return (
        "<bos><start_of_turn>user\n"
        f"You are a professional {source_name} ({source_code}) to {target_name} ({target_code}) translator. "
        f"Accurately convey the meaning and nuance of the original {source_name} text while using natural, fluent {target_name}. "
        f"Produce only the {target_name} translation, without explanations, options, labels, markdown, or commentary. "
        f"Please translate the following {source_name} text into {target_name}:\n\n"
        f"{text}"
        "<end_of_turn>\n"
        "<start_of_turn>model\n"
    )


def clean_output(text: str) -> str:
    output = text.strip()
    for marker in ("<end_of_turn>", "<eos>", "<start_of_turn>model", "<start_of_turn>"):
        if marker in output:
            output = output.split(marker, 1)[0].strip()
    output = re.sub(r"^(Dutch|French|English)\s*:\s*", "", output, flags=re.IGNORECASE)
    return output.strip()


def translate(text: str, model_dir: Path, source_code: str, target_code: str) -> str:
    try:
        from mlx_lm import generate, load
    except Exception as exc:
        raise RuntimeError(f"Could not load the TranslateGemma MLX runtime: {exc}") from exc

    model, tokenizer = load(str(model_dir))
    outputs: list[str] = []
    for chunk in text_chunks(text):
        prompt = build_prompt(chunk, source_code, target_code)
        generated = generate(
            model,
            tokenizer,
            prompt=prompt,
            max_tokens=320,
            verbose=False,
        )
        outputs.append(clean_output(generated))
    return " ".join(part for part in outputs if part).strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Translate text with a local TranslateGemma MLX model.")
    parser.add_argument("--from", dest="source", default="en", choices=sorted(LANGUAGE_NAMES))
    parser.add_argument("--to", required=True, choices=sorted(LANGUAGE_NAMES))
    parser.add_argument("--model-dir", required=True)
    args = parser.parse_args()

    text = sys.stdin.read().strip()
    if not text:
        return 0
    if args.source == args.to:
        sys.stdout.write(text)
        return 0

    try:
        translated = translate(text, Path(args.model_dir), args.source, args.to)
    except Exception as exc:
        sys.stderr.write(f"TranslateGemma local translation failed: {exc}\n")
        return 4

    sys.stdout.write(translated)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
