# DuckWhisperer

Native macOS dictation app powered by `whisper.cpp`.

DuckWhisperer records with `Option+Space`, transcribes locally, copies the transcript, and pastes it back into the app you were using. It is built to stay small in Git: Whisper models, translation packs, and the whisper.cpp framework are downloaded outside the committed source tree.

## Fresh Machine Setup

Requirements:

- macOS 13 or newer
- Xcode Command Line Tools
- Network access for the first install
- Python 3 if you want French or Dutch local translation output

Install:

```bash
git clone <repo-url> duckwhisperer
cd duckwhisperer
./scripts/install_app.sh
```

Then grant the macOS permissions:

- Microphone: required for recording
- Accessibility: required for automatic paste/type-back into the target app

Use `Option+Space` once to start recording and `Option+Space` again to stop, transcribe, and paste.

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

## Manual Build

```bash
./scripts/bootstrap_backend.sh
./scripts/build_app.sh
open dist/DuckWhisperer.app
```

To build only the lightweight app bundle without installing the default model or translation runtime:

```bash
INSTALL_DEFAULT_MODEL=0 INSTALL_TRANSLATION=0 ./scripts/build_app.sh
```

## Features

- Global shortcut: `Option+Space`
- Local English speech transcription
- Optional English -> French and English -> Dutch local output translation
- Model Explorer for `Small English`, `Base English`, and `Tiny English`
- Duck menu-bar icon and DuckWhisperer app icon
- `Preserve Capitalization` toggle
- Fallback transcript window when macOS does not allow auto-paste

## Models

No speech model is committed or bundled into the app.

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

Input speech is always treated as English. Output can be English, French, or Dutch.

French and Dutch output use local Argos Translate packages. Install them from Model Explorer, or run:

```bash
./scripts/setup_local_translation.sh
```

Translation runtime data is stored in:

```text
~/Library/Application Support/Local Whisperer/Translation
```

## macOS Permissions Note

This app is ad-hoc signed unless you add a Developer ID signing identity. macOS may reset Accessibility trust after rebuilding or reinstalling the app. If automatic paste stops working, toggle `DuckWhisperer` off and on in:

```text
System Settings -> Privacy & Security -> Accessibility
```

## Repository Hygiene

This repo intentionally excludes:

- `build/`
- `dist/`
- `vendor/`
- downloaded `.bin` Whisper models
- local Python virtual environments
- Argos translation package/runtime data
