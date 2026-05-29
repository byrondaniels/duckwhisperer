# Translation Quality Notes

DuckWhisperer now treats English -> French and English -> Dutch output differently from the older optional local packs.

## Tested Paths

- Argos Translate: small and easy to install, but too literal for office dictation.
- Helsinki/OPUS classic: under the disk cap, but user testing found Dutch output unacceptable.
- Helsinki/OPUS `tc-big`: fits near the 500 MB cap when using selected safetensors files, but still translated office idioms too literally in smoke tests.
- M2M100 418M CTranslate2 int8: about 489 MB installed, but still mistranslated business terms such as "deck" and "rough".
- Qwen 0.5B/1.5B local LLMs: under the cap in quantized MLX form, but the tested small models produced hallucinated or corrupted translations.
- Apple Translation high-fidelity: local, fast, and better on common idioms. It still needs glossary help for office terms such as "deck", so DuckWhisperer now normalizes those terms before translation.

## Apple Probe Findings

High-fidelity Apple Translation completed English -> Dutch and English -> French inside a real AppKit/SwiftUI app context. Typical latency after warmup was roughly 400-1,200 ms for office-length snippets.

Direct AppKit probe output on macOS 26.5:

- English -> Dutch, "The call ran long because the vendor kept circling back to the same issue." -> "De oproep duurde lang omdat de verkoper steeds terugkwam bij hetzelfde probleem." in 2,076 ms.
- English -> Dutch, "I'm going to duck out early today, but I'll review the contract tonight." -> "Ik ga vandaag vroeg weg, maar ik zal de contracten vanavond doornemen." in 530 ms.
- English -> French, "Can you move the standup to tomorrow morning and let the Amsterdam team know?" -> "Pouvez-vous reporter le stand-up à demain matin et informer l'équipe d'Amsterdam ?" in 694 ms.

Low-latency Apple Translation is not the default. It surfaced a separate Apple system download prompt for English and Dutch assets and stalled during the probe, so it is not production-grade first-run UX yet.

Command-line Apple Translation is not reliable for this app. A plain Swift command-line probe hung, while the same direct `TranslationSession` call worked from an AppKit app. DuckWhisperer therefore only attempts Apple system translation while the app lifecycle is running.
