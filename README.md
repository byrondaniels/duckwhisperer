# DuckWhisperer

Native macOS dictation app powered by `whisper.cpp`.

DuckWhisperer records with `Option+Space`, transcribes locally, copies the transcript, and pastes it back into the app you were using. It can output English, French, Dutch, or a ridiculous Duck mode. It can also translate selected French/Dutch text back to English with `Option+X`. It is built to stay small in Git: Whisper models, translation packs, and the whisper.cpp framework are downloaded outside the committed source tree.

## Fresh Machine Setup

Requirements:

- macOS 13 or newer
- Xcode Command Line Tools
- Network access for the first install
- Python 3 if you want French or Dutch local translation output

Install:

```bash
git clone https://github.com/byrondaniels/duckwhisperer.git duckwhisperer
cd duckwhisperer
./scripts/install_app.sh
```

Then grant the macOS permissions:

- Microphone: required for recording
- Accessibility: required for automatic paste/type-back into the target app

Use `Option+Space` once to start recording and `Option+Space` again to stop, transcribe, and paste.
Use `Option+X` to translate currently selected French or Dutch text back to English in a popup transcript window.

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

After the first setup, use this faster path when changing app code and reinstalling on the same machine:

```bash
./scripts/reinstall_app.sh
```

It rebuilds and replaces `/Applications/DuckWhisperer.app` without reinstalling speech models or translation runtime data.

To build only the lightweight app bundle without installing the default model or translation runtime:

```bash
INSTALL_DEFAULT_MODEL=0 INSTALL_TRANSLATION=0 ./scripts/build_app.sh
```

## Source Layout

- `Sources/LocalWhisperer/App`: app delegate, menu state, config, logging, launch helpers, errors
- `Sources/LocalWhisperer/Audio`: microphone capture and audio conversion
- `Sources/LocalWhisperer/Automation`: global shortcuts, Accessibility target detection, paste/type-back
- `Sources/LocalWhisperer/Models`: speech model metadata and model storage
- `Sources/LocalWhisperer/Transcription`: whisper.cpp wrapper and live chunking
- `Sources/LocalWhisperer/Translation`: Argos package management and local translation calls
- `Sources/LocalWhisperer/UI`: menu-bar icon, overlay, transcript window, model explorer
- `Sources/LocalWhisperer/Text`: Duck output rendering

## Features

- Global shortcut: `Option+Space`
- Local English speech transcription
- Optional English -> French and English -> Dutch local output translation
- Optional French -> English and Dutch -> English selected-text translation
- Duck output that turns the transcript into assorted quacks
- Transcription overlay progress percentage
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

Input speech is always treated as English. Output can be English, French, Dutch, or Duck.

French and Dutch output use local Argos Translate packages. Install them from Model Explorer, or run:

```bash
./scripts/setup_local_translation.sh
```

Translation runtime data is stored in:

```text
~/Library/Application Support/Local Whisperer/Translation
```

Duck output is built into the app. It does not require a model, package, or network call.

Selected-text translation uses the current `Output Language` as the source language. For example, if Output Language is `Dutch`, select Dutch text and press `Option+X`; DuckWhisperer translates it to English and opens the transcript window with the result.

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
