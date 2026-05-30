# Translation Quality Notes

DuckWhisperer now treats English -> French and English -> Dutch output as Apple system-translation routes, not as Argos/OPUS routes.

## Tested Paths

- Argos Translate: small and easy to install, but too literal for office dictation.
- Helsinki/OPUS classic: under the disk cap, but user testing found Dutch output unacceptable.
- Helsinki/OPUS `tc-big`: fits near the 500 MB cap when using selected safetensors files, but still translated office idioms too literally in smoke tests.
- M2M100 418M CTranslate2 int8: about 489 MB installed, but still mistranslated business terms such as "deck" and "rough".
- Qwen 0.5B/1.5B local LLMs: under the cap in quantized MLX form, but the tested small models produced hallucinated or corrupted translations.
- NLLB 600M CTranslate2 int8: about 604 MB installed, fast, but translated "draft" as drawing and dropped context in French.
- NLLB 1.3B CTranslate2 int8: about 1.3 GB installed, still too literal and dropped content in office sentences.
- MADLAD 3B GGUF: Apache-2.0 and available near/over the 1 GB range depending on quantization, but the tested Q2 file did not load in current llama.cpp and the Q4 file produced literal/awkward office translations.
- TranslateGemma 4B Q2 GGUF: about 1.7 GB, runnable, but the quantization made Dutch/French output too awkward to ship.
- TranslateGemma 4B MLX 4-bit: about 2.18 GB for the model plus a separate MLX runtime. This was the first local fallback candidate that handled office idioms well enough for DuckWhisperer.
- Apple Translation high-fidelity: local, fast, and better on common idioms. It still needs glossary help for office terms such as "deck", so DuckWhisperer now normalizes those terms before translation.

## Product Decision

Default Dutch and French do not silently fall back to Argos or OPUS. If Apple local translation is unavailable and the validated TranslateGemma fallback is not installed, DuckWhisperer tells the user to open `Settings -> Prepare Apple Translation...` or install the high-quality fallback from `Speed & Accuracy`.

TranslateGemma fallback is explicit and removable. It is only used for default English -> Dutch/French when Apple Translation is unavailable or errors and the user has installed the fallback pack. OPUS remains available only through explicit test output choices.

The fallback cap was raised from 500 MB to 1 GB during testing, but no sub-1 GB candidate was good enough. The selected fallback is larger because the smaller models failed the office-language tests.

## Fallback Benchmark

The reproducible harness is:

```bash
tools/translation_fallback_benchmark.py --candidate translategemma-mlx --model-dir /path/to/translategemma-model --output /tmp/duckwhisperer-translategemma-mlx-results.jsonl
```

Validated TranslateGemma MLX outputs after the app's office-context normalization:

- English -> Dutch, "Please send the presentation deck..." -> "Verzend de presentatie naar de klant vóór de lunch. De huidige versie moet nog worden verfijnd, maar pas de cijfers niet aan."
- English -> Dutch, "I'm going to duck out early..." -> "Ik ga vandaag vroeg vertrekken, maar ik zal het contract vanavond doornemen."
- English -> French, "The meeting ran longer..." -> "La réunion a duré plus longtemps que prévu, car le fournisseur continuait à revenir sur le même problème."
- English -> French, "Let's table that issue..." -> "Mettons de côté cette question pour la semaine prochaine afin de nous concentrer sur le plan de lancement aujourd'hui."

Warm sentence latency on the tested Mac was roughly 0.9-1.5 seconds after model load. The model license is the Gemma license, so commercial distribution should be reviewed before bundling or redistributing weights. DuckWhisperer does not bundle the model; users download it locally only after approval.

## Apple Probe Findings

High-fidelity Apple Translation completed English -> Dutch and English -> French inside a real AppKit/SwiftUI app context. Typical latency after warmup was roughly 400-1,200 ms for office-length snippets.

Direct AppKit probe output on macOS 26.5:

- English -> Dutch, "The call ran long because the vendor kept circling back to the same issue." -> "De oproep duurde lang omdat de verkoper steeds terugkwam bij hetzelfde probleem." in 2,076 ms.
- English -> Dutch, "I'm going to duck out early today, but I'll review the contract tonight." -> "Ik ga vandaag vroeg weg, maar ik zal de contracten vanavond doornemen." in 530 ms.
- English -> French, "Can you move the standup to tomorrow morning and let the Amsterdam team know?" -> "Pouvez-vous reporter le stand-up à demain matin et informer l'équipe d'Amsterdam ?" in 694 ms.

Low-latency Apple Translation is not the default. It surfaced a separate Apple system download prompt for English and Dutch assets and stalled during the probe, so it is not production-grade first-run UX yet.

Command-line Apple Translation is not reliable for this app. A plain Swift command-line probe hung, while the same direct `TranslationSession` call worked from an AppKit app. DuckWhisperer therefore only attempts Apple system translation while the app lifecycle is running. The in-app Translation Pond window uses Apple's UI-backed `prepareTranslation()` route to request missing local assets with user permission.
