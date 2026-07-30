# AyuGram Desktop — maintained integration

Private integration and build repository for keeping AyuGram aligned with the current Telegram Desktop codebase.

## Current target

- AyuGram source: `PH4N7OMx/AyuGramDesktop`
- Pinned source commit: `aade78974c8634dd35168012f42585ebd8eb81e4`
- Telegram Desktop version: `7.0.6`
- Windows artifact: `AyuGram.exe` / `ayusetup-x64.7.0.6.exe`

The source commit is fetched from scratch by GitHub Actions and modified only by versioned patches stored in this repository. Auto-update is disabled until this fork owns an update endpoint and signing key.

## Status

Work in progress. A release is not accepted until the Windows x64 workflow produces and validates the executable and installer artifacts.
