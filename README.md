# DuckWhisperer

Native macOS dictation app powered by `whisper.cpp`.

DuckWhisperer records with `Option+Space`, transcribes locally, copies the transcript, and pastes it back into the app you were using. It can output English, French, Dutch, British, Gen Z, or a ridiculous Duck mode. It is built to stay small in Git: Whisper models, translation packs, and the whisper.cpp framework are downloaded outside the committed source tree.

## Fresh Machine Setup

Requirements:

- macOS 13 or newer
- Xcode Command Line Tools
- Network access for the first install
- Python 3.11, 3.12, or 3.13 if you want local French/Dutch translation

Install:

```bash
git clone https://github.com/byrondaniels/duckwhisperer.git duckwhisperer
cd duckwhisperer
./scripts/doctor.sh
./scripts/install_app.sh
```

Then grant the macOS permissions:

- Microphone: required for recording
- Accessibility: required for automatic paste/type-back into the target app

Use `Option+Space` once to start recording and `Option+Space` again to stop, transcribe, and paste.
Press `Escape` while recording or transcribing to cancel without pasting.

Open the menu-bar duck for writing profiles, transcript history, app-specific defaults, personal dictionary, audio ducking, model speed/quality, and Setup Doctor.

## What Gets Installed

The app bundle is installed at:

```text
/Applications/DuckWhisperer.app
```

Runtime assets are installed outside the repo and app bundle at:

```text
~/Library/Application Support/Local Whisperer
```

That folder contains downloaded speech models and optional translation runtime data. It is not committed to Git.

The default install sets up transcription only. Local translation can be added later from Model Explorer or with:

```bash
./scripts/setup_local_translation.sh
```

To force translation setup during install:

```bash
INSTALL_TRANSLATION=1 ./scripts/install_app.sh
```

## Manual Build

```bash
./scripts/bootstrap_backend.sh
./scripts/build_app.sh
open dist/DuckWhisperer.app
```

After the first setup, use this faster path when changing app code and reinstalling on the same machine:

```bash
./scripts/reinstall_app.sh
```

It rebuilds and replaces `/Applications/DuckWhisperer.app` without reinstalling speech models or translation runtime data.

To build only the lightweight app bundle without installing the default model or translation runtime:

```bash
INSTALL_DEFAULT_MODEL=0 INSTALL_TRANSLATION=0 ./scripts/build_app.sh
```

## Release Package

Build a drag-and-drop macOS package with the default `Small English` speech model bundled inside the app:

```bash
./scripts/package_release.sh
```

The release artifact is written to `release/`. By default this creates a `.zip`; set `PACKAGE_FORMAT=dmg` or `PACKAGE_FORMAT=both` if needed.

This packaged app can transcribe English without a terminal setup or model download. macOS still requires the user to grant Microphone and Accessibility permissions after installing. French/Dutch translation remains optional and can be installed later from Model Explorer.

The build script automatically uses a local code-signing identity when one is available, preferring `Developer ID Application` and then local Apple development identities. If no identity exists, it falls back to ad-hoc signing.

For release packages meant for other Macs, use a Developer ID certificate:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package_release.sh
```

To force an ad-hoc local build:

```bash
SIGNING_IDENTITY=- ./scripts/build_app.sh
```

Run the full local verification loop before pushing changes:

```bash
./scripts/verify.sh
```

## Source Layout

- `Sources/LocalWhisperer/App`: app delegate, menu state, config, logging, launch helpers, errors
- `Sources/LocalWhisperer/Audio`: microphone capture and audio conversion
- `Sources/LocalWhisperer/Automation`: global shortcuts, Accessibility target detection, paste/type-back
- `Sources/LocalWhisperer/Models`: speech model metadata and model storage
- `Sources/LocalWhisperer/Transcription`: whisper.cpp wrapper and live chunking
- `Sources/LocalWhisperer/Translation`: Argos package management and local translation calls
- `Sources/LocalWhisperer/UI`: menu-bar icon, overlay, transcript window, model explorer
- `Sources/LocalWhisperer/Text`: output styles, writing profiles, command phrases, and dictionary replacement

## Features

- Global shortcut: `Option+Space`
- Active dictation cancel shortcut: `Escape`
- Local English speech transcription
- Optional English -> French and English -> Dutch local output translation
- Built-in British and Gen Z style output modes
- Writing profiles: Smart Clean, Raw Dictation, Clean Email, Slack Casual, Meeting Notes, Code Prompt, and Bullet Notes
- Command phrases such as "make this shorter", "turn this into bullets", "rewrite professionally", "translate to Dutch", and "duck mode"
- Per-app defaults for model, output language, and writing profile
- Personal dictionary replacements stored locally
- Searchable local transcript history
- Optional audio ducking while recording
- Speed / Quality menu for Fast, Balanced, and Accurate model choices
- Setup Doctor for microphone, Accessibility, model, install, and signing checks
- Duck output that turns the transcript into assorted quacks
- Audio-reactive duck recording overlay with live preview, elapsed time, profile/model context, cancel hint, and transcription progress percentage
- Model Explorer for `Small English`, `Base English`, and `Tiny English`
- Duck menu-bar icon and DuckWhisperer app icon
- `Preserve Capitalization` toggle
- Fallback transcript window when macOS does not allow auto-paste

## Models

No speech model is committed to Git. Normal source builds keep speech models outside the app bundle in Application Support. Release packages created by `./scripts/package_release.sh` bundle `Small English` inside `DuckWhisperer.app` so a fresh Mac can transcribe English without a separate model download.

Default model:

- `Small English`
- about 487.6 MB
- best default for English dictation

Optional models:

- `Base English`, about 148.0 MB
- `Tiny English`, about 77.7 MB

Downloaded models are stored in:

```text
~/Library/Application Support/Local Whisperer/Models
```

## Translation

Input speech is always treated as English. Output can be English, French, Dutch, British, Gen Z, or Duck.

French and Dutch output use local Argos Translate packages. Install them from Model Explorer, or run:

```bash
./scripts/setup_local_translation.sh
```

The translation setup intentionally avoids Python versions that would require native source builds. It currently looks for Python 3.13, then 3.12, then 3.11, and installs `argostranslate==1.11.0` plus `sentencepiece==0.2.1` from binary wheels.

Translation runtime data is stored in:

```text
~/Library/Application Support/Local Whisperer/Translation
```

Duck output is built into the app. It does not require a model, package, or network call.

British and Gen Z output are built-in text style modes. They do not require a model, package, or network call.

## Product Features

Writing profiles are deterministic local cleanup modes. They do not call a cloud model. Pick a default profile from the menu, or save a per-app default so Slack, Mail, Codex, and Notes can each use a different model/language/profile combination.

The personal dictionary is a local text list of replacements, one per line:

```text
open ai = OpenAI
duck whisperer = DuckWhisperer
```

Transcript history stores recent outputs locally in macOS user defaults. Use the history menu to copy recent transcripts or open the searchable history window.

Command phrases are interpreted at the start of a dictation. For example, saying "turn this into bullets follow up with Alex and ship the build" applies the Bullet Notes profile to the remaining text.

Audio ducking lowers system output volume while recording and restores it afterward. It is off by default.

## macOS Permissions Note

macOS ties Accessibility permission to the app's code-signing requirement. DuckWhisperer will use a stable local signing identity when one exists; that makes paste permission more likely to survive rebuilds. Ad-hoc builds are identified by a changing code hash, so macOS may reset Accessibility trust after rebuilding or reinstalling the app.

If automatic paste stops working, toggle `DuckWhisperer` off and on in:

```text
System Settings -> Privacy & Security -> Accessibility
```

Run `./scripts/doctor.sh` to see whether the installed app is ad-hoc signed or has a stable signing requirement.

## Repository Hygiene

This repo intentionally excludes:

- `build/`
- `dist/`
- `vendor/`
- downloaded `.bin` Whisper models
- local Python virtual environments
- Argos translation package/runtime data
