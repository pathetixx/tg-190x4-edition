# Upstream and release workflow

The fork tracks Telegram Desktop in two separate ways:

- `dev` is the integration stream. It is useful for resolving fork conflicts early, but it is not a release version by itself.
- `vX.Y.Z` tags are the stable stream. A stable fork release should be based on a Telegram tag and should keep the same Telegram version in `Telegram/build/version`.

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

The script creates a separate `sync/upstream/...` branch, enables Git rerere, aborts on conflicts, and runs the fork invariant checks before committing. Conflicts in fork code remain a deliberate maintainer decision; they are not silently overwritten.

The Windows installer is per-user and is registered by Inno Setup in the current user's installed-programs list. It installs to the existing user-data-compatible location so the built-in updater can replace files without requiring administrator rights. The portable ZIP remains a separate artifact.

Releases are built by the `Windows x64` workflow on GitHub Actions. Nothing is
compiled by hand any more.

The workflow is split so that a failed stage can be re-run on its own:

- `verify-fork` — fork invariants, runs on pull requests too.
- `libraries` — builds the third-party libraries into the Actions cache. It uses
  no secrets. The cache is written even when the step fails or runs out of time,
  so re-running only this job continues from the stages that already finished.
- `build` — configures and compiles the client with auto-update enabled and
  uploads `TG190x4.exe`, `Updater.exe` and `Packer.exe`.
- `package` — builds the installer and the portable archive with checksums.
- `publish` — creates the GitHub release and publishes the update package. Runs
  only for `ayugram-v*` tags.

`workflow_dispatch` runs everything except `publish`, which is the way to check a
branch before tagging it.

Release notes are taken from the annotated tag, and `publish` fails if the tag
carries none or if the tag does not match `AppVersionStr`:

```bash
git tag -a ayugram-v7.1.1 -m "..." && git push origin ayugram-v7.1.1
```

Auto-update is enabled by passing `TG190X4_ENABLE_AUTOUPDATE=ON` together with
`TG190X4_UPDATE_PREFIX` to `build_tg190x4.bat`. The prefix must not end with a
slash: the client appends `/current4` and the package path to it.
`TG190X4_PREPARE_ONLY=1` stops the script once the libraries are ready, which is
what the `libraries` job uses.

Update packages are signed with an RSA-2048 fork key. The public halves live in
`Telegram/SourceFiles/config.h` and `Telegram/SourceFiles/_other/packer.cpp`.
The private halves belong in `Telegram/SourceFiles/_other/packer_private.h`,
which is ignored by git and must never be committed. Losing the private key
means installed clients stop accepting updates and have to be replaced by hand.

A local build can still publish an update by hand:

```powershell
pwsh -File scripts/publish_update.ps1 -Publish
```

The script runs Packer over `TG190x4.exe` and `Updater.exe`, writes the
`current4` manifest and uploads both as the latest release of the update
channel repository. Without `-Publish` it only prepares the files locally.

Clients compare the `released` number in the manifest against their own
`AppVersion`, so an update only reaches builds with a lower version.
