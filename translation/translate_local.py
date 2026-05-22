#!/usr/bin/env python3
import argparse
import sys


LANGUAGE_NAMES = {
    "fr": "French",
    "nl": "Dutch",
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Translate English text with local Argos models.")
    parser.add_argument("--to", required=True, choices=sorted(LANGUAGE_NAMES))
    args = parser.parse_args()

    text = sys.stdin.read().strip()
    if not text:
        return 0

    try:
        from argostranslate import translate
    except Exception as exc:
        sys.stderr.write(f"Could not load Argos Translate: {exc}\n")
        return 2

    languages = {language.code: language for language in translate.get_installed_languages()}
    source = languages.get("en")
    target = languages.get(args.to)
    if source is None or target is None:
        sys.stderr.write(
            f"Missing local Argos Translate package for English -> {LANGUAGE_NAMES[args.to]}.\n"
        )
        return 3

    try:
        translated = source.get_translation(target).translate(text)
    except Exception as exc:
        sys.stderr.write(f"Local translation failed: {exc}\n")
        return 4

    sys.stdout.write(translated.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
