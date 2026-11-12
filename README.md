# Rayfish Nix flake

Rayfish for x86_64/aarch64 Linux and Apple Silicon macOS, using nixpkgs unstable
and pinned inputs in `flake.lock`.

```sh
nix build
nix run . -- --help
```

Linux builds the CLI/daemon from source in release mode, with Rust
`target-cpu=native` and C `-march=native` (`-mcpu=native` on ARM). Its browser UI is available through
`ray gui`; there is no separate Linux desktop app. Build on the machine that
will run it: native binaries are not portable between different CPUs. Local
builds are preferred and binary substitution is disabled for this package.

macOS defaults to the upstream signed, notarized graphical app, including its
bundled CLI. Copy `result/Applications/Rayfish.app` to `/Applications`, launch
it, and approve its network extension. The app must live in `/Applications`
for Apple's extension registration; do not launch it directly in the Nix store.
This is a prebuilt app, **not** a native-optimized source build: a working
source-built GUI requires Xcode, Apple signing identities, and provisioning
profiles that cannot be supplied by a generic Nix flake.

`nix build .#cli` builds the native-optimized standalone CLI/daemon on either
platform. On macOS, choose either the app or the standalone daemon, not both.
This flake packages software only; it does not configure a system service.

GitHub Actions checks for stable releases and refreshes nixpkgs every Monday
at 11:23 UTC (also runnable manually). It builds and smoke-tests the Linux CLI
before opening an update PR, then enables squash auto-merge. Every PR also runs
the independent `Linux build` check, including upstream CLI tests.

The updater uses the built-in `GITHUB_TOKEN` and explicitly dispatches the PR
checks, since bot-created PRs do not trigger `pull_request` workflows. No personal
token or additional secret is needed.

Configure the GitHub repository once:

- Enable **Allow GitHub Actions to create and approve pull requests** in Actions settings.
- Enable **Allow auto-merge** and **Allow squash merging** in repository settings.
- Protect the default branch with a rule requiring pull requests and the
  **Linux build** status check. Do not require manual approvals for these updates
  if they should merge unattended. Auto-merge respects all branch rules; it does
  not bypass failing checks or required reviews. The check may need to run once
  before GitHub offers it in the required-checks picker.
