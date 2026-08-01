# Upstream and release workflow

The fork tracks Telegram Desktop in two separate ways:

- `dev` is the integration stream. It is useful for resolving AyuGram conflicts early, but it is not a release version by itself.
- `vX.Y.Z` tags are the stable stream. A stable AyuGram release should be based on a Telegram tag and should keep the same Telegram version in `Telegram/build/version`.

Preview the current integration delta:

```powershell
pwsh -File scripts/sync_upstream.ps1 -Ref dev
```

Preview the newest stable tag:

```powershell
pwsh -File scripts/sync_upstream.ps1 -LatestStable
```

Apply a merge only from a clean worktree:

```powershell
pwsh -File scripts/sync_upstream.ps1 -Ref dev -Apply
```

The script creates a separate `sync/upstream/...` branch, enables Git rerere, aborts on conflicts, and runs the fork invariant checks before committing. Conflicts in AyuGram code remain a deliberate maintainer decision; they are not silently overwritten.

The Windows installer is per-user and is registered by Inno Setup in the current user's installed-programs list. It installs to the existing user-data-compatible location so the built-in updater can replace files without requiring administrator rights. The portable ZIP remains a separate artifact.

Auto-update is disabled by default in local and CI builds. The source tree still contains Telegram Desktop's updater implementation, but enabling it before the fork owns an update endpoint and a private signing key could install releases from the wrong channel. The intended OTA sequence is:

1. Create a fork-owned update endpoint with stable and beta manifests.
2. Generate a new signing key pair outside the repository and keep only the public key in source.
3. Produce signed update payloads in a protected release job.
4. Verify signature, version, architecture, and rollback behavior on a clean installed copy.
5. Set `AYUGRAM_UPDATE_PREFIX` to the fork-owned endpoint, then enable `AYUGRAM_ENABLE_AUTOUPDATE=ON` only after those checks pass. The builder rejects the old endpoint or the official Telegram signing key.
