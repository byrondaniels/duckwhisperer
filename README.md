# Plume

Private voice typing for every Mac app.

Press `Option+Space`, talk naturally, press `Option+Space` again, and Plume turns your voice into polished text anywhere your cursor already is. Transcription runs locally on your Mac, so your voice stays on your machine. It can listen in English by default, with optional local input support for Spanish, French, Tagalog, and other common languages. Output defaults to `Same as Input`, or you can choose English, French, Dutch, British, Gen Z, Alien, Cowboy, Pirate, Robot, Shakespeare, or a ridiculous Quack mode.

## Quick Start

If you have a packaged release:

1. Open the Plume DMG.
2. Drag `Plume.app` to `Applications`.
3. Open it.
4. In the menu-bar icon, open `Finish Setup`.
5. Allow Microphone and paste-back permissions.
6. Open `Try It Here...` and do your first test.

Use `Option+Space` once to start recording and `Option+Space` again to stop, transcribe, and paste.
Press `Escape` while recording or transcribing to cancel without pasting.

Open the menu-bar icon for `Try It Here`, `Undo Last Paste`, `I Speak`, `Output`, `Writing Style`, `Speed & Accuracy`, `History`, and `Settings`.

## Fresh Machine Setup

Requirements:

- macOS 13 or newer
- Xcode Command Line Tools
- Network access for the first install
- Python 3.11, 3.12, or 3.13 if you want local French/Dutch translation

Install:

```bash
git clone <repository-url> plume
cd plume
./scripts/doctor.sh
./scripts/install_app.sh
```

Then grant the macOS permissions:

- Microphone: required for recording
- Accessibility: required for automatic paste/type-back into the target app

## What Gets Installed

The app bundle is installed at:

```text
/Applications/Plume.app
```

Runtime assets are installed outside the repo and app bundle at:

```text
~/Library/Application Support/Plume
```

That folder contains downloaded speech models, optional translation runtime data, and optional local style-rewrite assets. It is not committed to Git.

The default install sets up transcription only. Local translation can be added later from `Speed & Accuracy` or with:

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
open dist/Plume.app
```

After the first setup, use this faster path when changing app code and reinstalling on the same machine:

```bash
./scripts/reinstall_app.sh
```

It rebuilds and replaces `/Applications/Plume.app` without reinstalling speech models or translation runtime data.

To build only the lightweight app bundle without installing the default model or translation runtime:

```bash
INSTALL_DEFAULT_MODEL=0 INSTALL_TRANSLATION=0 ./scripts/build_app.sh
```

## Release Package

Build a drag-and-drop macOS package with the default `Best Accuracy` speech model bundled inside the app:

```bash
./scripts/package_release.sh
```

The release artifact is written to `release/`. By default this creates a `.dmg` with `Plume.app`, an `Applications` shortcut, and `Start Here.html`. Set `PACKAGE_FORMAT=zip` or `PACKAGE_FORMAT=both` if needed.

This packaged app can transcribe English without a terminal setup or model download. macOS still requires the user to grant Microphone and paste-back permissions after installing. French/Dutch translation remains optional and can be installed later from `Speed & Accuracy`.

See `docs/release-workflow.md` for the full non-developer install test, signing notes, and release checklist.

The build script automatically uses a local code-signing identity when one is available, preferring `Developer ID Application` and then local Apple development identities. If no identity exists, it falls back to ad-hoc signing.

For release packages meant for other Macs, use a Developer ID certificate:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package_release.sh
```

Then notarize the DMG:

```bash
NOTARYTOOL_PROFILE=plume-release ./scripts/notarize_release.sh
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

- `Sources/Plume/App`: app delegate, menu state, config, logging, launch helpers, errors
- `Sources/Plume/Audio`: microphone capture and audio conversion
- `Sources/Plume/Automation`: global shortcuts, Accessibility target detection, paste/type-back
- `Sources/Plume/Models`: speech model metadata and model storage
- `Sources/Plume/Transcription`: whisper.cpp wrapper and live chunking
- `Sources/Plume/Translation`: Argos package management and local translation calls
- `Sources/Plume/UI`: menu-bar icon, overlay, transcript window, model explorer
- `Sources/Plume/Text`: output styles, writing profiles, command phrases, and dictionary replacement

## Features

- Global shortcut: `Option+Space`
- Active dictation cancel shortcut: `Escape`
- Built-in `Try It Here` window for first-run testing
- `Undo Last Paste` for fast recovery when text lands in the wrong place
- Local speech transcription with lazy input-language downloads
- Built-in input choices for English, Spanish, French, Tagalog, Chinese, Hindi, Arabic, Bengali, Portuguese, Russian, Urdu, Indonesian, German, Japanese, Korean, Turkish, Vietnamese, Italian, Polish, and Dutch
- Optional English -> French/Dutch output translation plus per-language input -> English translator downloads
- Built-in British, Gen Z, Alien, Cowboy, Pirate, Robot, Shakespeare, and Quack style modes
- Optional Enhanced Robot mode with a Plume-managed local llama.cpp runner
- Writing profiles: Smart Clean, Raw Dictation, Clean Email, Slack Casual, Meeting Notes, Code Prompt, and Bullet Notes
- Command phrases such as "make this shorter", "turn this into bullets", "rewrite professionally", "translate to Dutch", "alien mode", "cowboy mode", and "quack mode"
- Green HUD command badge when a spoken command phrase is recognized
- Per-app defaults for model, output language, and writing profile
- Personal dictionary replacements stored locally
- Searchable local transcript history
- Local time-saved tracker based on words dictated, speaking time, and estimated typing time
- Optional audio ducking while recording
- `Speed & Accuracy` menu for Best Accuracy, Fast, and Fastest choices
- `Finish Setup` for microphone, paste-back, model, install, and app identity checks
- `Presenter Mode` for camera-readable TikTok/product demos
- Fun language modes that transform the transcript locally without extra downloads
- Audio-reactive plume recording overlay with live preview, elapsed time, profile/model context, cancel hint, and transcription progress percentage
- Paste recovery window with `Paste Again`, `Copy`, and `Fix Permission`
- Plume menu-bar icon and app icon
- `Preserve Capitalization` toggle
- Fallback transcript window when macOS does not allow auto-paste

## Input Languages

English input uses the smaller English-only speech model. Non-English input uses one shared multilingual Whisper model for the selected speed. Plume does not download one speech pack per language; the first non-English language you choose asks for approval, then that one shared speech model unlocks the other non-English input languages for that speed.

`I Speak` controls what language you speak. `Output` controls what text comes back. `Same as Input` keeps Spanish speech as Spanish text, French speech as French text, and so on. Choosing `English` while speaking a non-English input language uses a dedicated local text translator when that language pair is installed, with Whisper's local speech-translation mode as the fallback.

## Models

No speech model is committed to Git. Normal source builds keep speech models outside the app bundle in Application Support. Release packages created by `./scripts/package_release.sh` bundle `Best Accuracy` inside `Plume.app` so a fresh Mac can transcribe English without a separate model download.

Default model:

- `Best Accuracy`, internally `Small English`
- about 487.6 MB
- best default for English dictation

Optional models:

- `Fast`, internally `Base English`, about 148.0 MB
- `Fastest`, internally `Tiny English`, about 77.7 MB

Extra language file sizes:

- `Best Accuracy`, about 488.0 MB
- `Fast`, about 148.0 MB
- `Fastest`, about 77.7 MB

Downloaded models are stored in:

```text
~/Library/Application Support/Plume/Models
```

## Translation

Output defaults to `Same as Input`. You can also choose English, French, Dutch, British, Gen Z, Alien, Cowboy, Pirate, Robot, Shakespeare, or Quack.

Non-English input to English can use individual local text translators. For example, Tagalog -> English installs only the Tagalog -> English translator, then Plume transcribes Tagalog text first and translates that text to English. If the matching translator is not installed, the app asks before downloading it.

French and Dutch output use local Argos Translate packages after the transcript is available in English. Install them from `Speed & Accuracy`, or run:

```bash
./scripts/setup_local_translation.sh
```

The translation setup intentionally avoids Python versions that would require native source builds. The Argos setup currently looks for Python 3.13, then 3.12, then 3.11, and installs `argostranslate==1.11.0` plus `sentencepiece==0.2.1` from binary wheels. Dedicated input -> English translators are lazy installs from `Speed & Accuracy`; the first one may also install a local Transformers/PyTorch runtime.

Translation runtime data is stored in:

```text
~/Library/Application Support/Plume/Translation
```

Fun modes are built into the app. British, Gen Z, Alien, Cowboy, Pirate, Shakespeare, and Quack output do not require a model, package, or network call. Robot works immediately in basic mode, and can optionally be upgraded to Enhanced Robot from `Speed & Accuracy`.

Enhanced Robot installs its own local llama.cpp runner plus `qwen2.5-0.5b-instruct-q4_k_m.gguf`. It does not require Ollama, a server process, or a cloud API. The optional download is about 491 MB for the model plus about 8 MB for the runner, and it is only downloaded after you approve the install.

Enhanced Robot assets are stored in:

```text
~/Library/Application Support/Plume/StyleRewriter
```

## Product Features

Writing profiles are deterministic local cleanup modes. They do not call a cloud model. Pick a default profile from the menu, or save a per-app default so Slack, Mail, Codex, and Notes can each use a different model/language/profile combination.

The personal dictionary is a local text list of replacements, one per line:

```text
open ai = OpenAI
plume = Plume
```

Transcript history stores recent outputs locally in macOS user defaults. Use the history menu to copy recent transcripts or open the searchable history window.

Command phrases are interpreted at the start of a dictation. For example, saying "turn this into bullets follow up with Alex and ship the build" applies the Bullet Notes profile to the remaining text.

Audio ducking lowers system output volume while recording and restores it afterward. It is off by default.

Presenter Mode makes the recording overlay larger and hides technical context so the app reads clearly on camera. See `docs/tiktok-demo-scripts.md` for short demo ideas.

## macOS Permissions Note

macOS ties Accessibility permission to the app's code-signing requirement. Plume will use a stable local signing identity when one exists; that makes paste permission more likely to survive rebuilds. Ad-hoc builds are identified by a changing code hash, so macOS may reset Accessibility trust after rebuilding or reinstalling the app.

If automatic paste stops working, toggle `Plume` off and on in:

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
