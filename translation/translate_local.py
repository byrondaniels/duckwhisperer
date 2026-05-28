#!/usr/bin/env python3
import argparse
import re
import sys


LANGUAGE_NAMES = {
    "ar": "Arabic",
    "bn": "Bengali",
    "de": "German",
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "hi": "Hindi",
    "id": "Indonesian",
    "it": "Italian",
    "ja": "Japanese",
    "ko": "Korean",
    "nl": "Dutch",
    "pl": "Polish",
    "pt": "Portuguese",
    "ru": "Russian",
    "tl": "Tagalog",
    "tr": "Turkish",
    "ur": "Urdu",
    "vi": "Vietnamese",
    "zh": "Chinese",
}


def text_chunks(text: str, max_words: int = 180) -> list[str]:
    rough_parts = re.split(r"(?<=[.!?])\s+|\n+", text)
    chunks: list[str] = []
    for part in rough_parts:
        words = part.strip().split()
        while words:
            chunk_words = words[:max_words]
            chunks.append(" ".join(chunk_words))
            words = words[max_words:]
    return chunks or [text]


def translate_with_huggingface(text: str, model_dir: str, source_prefix: str | None = None) -> str:
    try:
        import torch
        from transformers import AutoModelForSeq2SeqLM, AutoTokenizer
    except Exception as exc:
        raise RuntimeError(f"Could not load the dedicated translator runtime: {exc}") from exc

    tokenizer = AutoTokenizer.from_pretrained(model_dir, local_files_only=True, use_fast=False)
    model = AutoModelForSeq2SeqLM.from_pretrained(model_dir, local_files_only=True)
    model.eval()

    outputs = []
    with torch.no_grad():
        for chunk in text_chunks(text):
            if source_prefix:
                chunk = f"{source_prefix} {chunk}"
            encoded = tokenizer(
                chunk,
                return_tensors="pt",
                truncation=True,
                max_length=512,
            )
            generated = model.generate(
                **encoded,
                max_new_tokens=512,
                num_beams=4,
            )
            outputs.append(tokenizer.decode(generated[0], skip_special_tokens=True).strip())

    return " ".join(part for part in outputs if part).strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Translate text with local Argos models.")
    parser.add_argument("--from", dest="source", default="en", choices=sorted(LANGUAGE_NAMES))
    parser.add_argument("--to", required=True, choices=sorted(LANGUAGE_NAMES))
    parser.add_argument("--hf-model-dir", help="Use a local Hugging Face Marian model directory instead of Argos.")
    parser.add_argument("--source-prefix", help="Prefix each source chunk, for multilingual Marian target tags.")
    args = parser.parse_args()

    text = sys.stdin.read().strip()
    if not text:
        return 0

    if args.hf_model_dir:
        try:
            translated = translate_with_huggingface(text, args.hf_model_dir, args.source_prefix)
        except Exception as exc:
            sys.stderr.write(f"Dedicated local translation failed: {exc}\n")
            return 4
        sys.stdout.write(translated.strip())
        return 0

    try:
        from argostranslate import translate
    except Exception as exc:
        sys.stderr.write(f"Could not load Argos Translate: {exc}\n")
        return 2

    languages = {language.code: language for language in translate.get_installed_languages()}
    source = languages.get(args.source)
    target = languages.get(args.to)
    if source is None or target is None:
        sys.stderr.write(
            f"Missing local Argos Translate package for {LANGUAGE_NAMES[args.source]} -> {LANGUAGE_NAMES[args.to]}.\n"
        )
        return 3

    try:
        translation = source.get_translation(target)
        if translation is None:
            sys.stderr.write(
                f"Missing local Argos Translate package for {LANGUAGE_NAMES[args.source]} -> {LANGUAGE_NAMES[args.to]}.\n"
            )
            return 3
        translated = translation.translate(text)
    except Exception as exc:
        sys.stderr.write(f"Local translation failed: {exc}\n")
        return 4

    sys.stdout.write(translated.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
