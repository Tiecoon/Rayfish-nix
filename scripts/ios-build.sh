# Invoked by the flake's ios-build app, with pinned source/toolchain variables.
set -euo pipefail

usage() {
    echo 'Usage: nix run .#ios-build -- prepare|open|build DIRECTORY' >&2
    echo 'prepare requires IOS_BUNDLE_ID; build requires IOS_TEAM_ID and IOS_DEVICE (UDID).' >&2
    exit 1
}
[[ $# == 2 ]] || usage
mode=$1
work=$2
case "$mode" in prepare|open|build) ;; *) usage ;; esac

if [[ "$mode" == prepare ]]; then
    : "${IOS_BUNDLE_ID:?Set a unique bundle ID, e.g. com.example.rayfish}"
    if [[ ! "$IOS_BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
        echo 'IOS_BUNDLE_ID must be a reverse-DNS identifier.' >&2
        exit 1
    fi
    if [[ -e "$work" ]]; then
        echo "Refusing to overwrite existing path: $work" >&2
        exit 1
    fi
    mkdir -p "$work"
    cp -R "$RAYFISH_SOURCE/." "$work/"
    chmod -R u+w "$work"
    # Keep the app, both extensions, shared storage and device installer aligned.
    python3 - "$work/ios" "$IOS_BUNDLE_ID" "$PATH" "$RUSTUP_TOOLCHAIN" <<'PY'
from pathlib import Path
import shlex
import sys

for path in Path(sys.argv[1]).rglob("*"):
    if path.suffix in {".swift", ".yml", ".plist", ".entitlements", ".sh", ".pbxproj"}:
        text = path.read_text()
        if "xyz.rayfish.ios" in text:
            path.write_text(text.replace("xyz.rayfish.ios", sys.argv[2]))

# Xcode build phases reset PATH; keep Nix's rustup available even from Finder.
script = Path(sys.argv[1]) / "build-rust.sh"
text = script.read_text()
text = text.replace('export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:$PATH"',
                    'export PATH=' + shlex.quote(sys.argv[3])
                    + '\nexport RUSTUP_TOOLCHAIN=' + shlex.quote(sys.argv[4]), 1)
script.write_text(text)
PY
    printf '%s\n' "$RAYFISH_REV" > "$work/.rayfish-nix-revision"
fi

if [[ ! -f "$work/.rayfish-nix-revision" ]] || [[ "$(cat "$work/.rayfish-nix-revision")" != "$RAYFISH_REV" ]]; then
    echo 'Use prepare with a new directory for this pinned Rayfish revision.' >&2
    exit 1
fi
work=$(realpath "$work")
if [[ "$mode" == prepare ]]; then
    xcodegen generate --spec "$work/ios/project.yml" --project "$work/ios"
    echo "Prepared $work. Next: nix run .#ios-build -- open \"$work\""
    exit 0
fi

if [[ "$mode" == build ]]; then
    : "${IOS_TEAM_ID:?Set your Apple Developer team ID}"
    : "${IOS_DEVICE:?Set the paired iPhone UDID from xcrun devicectl list devices}"
fi

# The Apple SDK/compiler and signing keychain must come from local full Xcode.
xcrun --sdk iphoneos --show-sdk-path >/dev/null
rustup toolchain install "$RUSTUP_TOOLCHAIN" --profile minimal \
    --target aarch64-apple-ios --target aarch64-apple-ios-sim
if [[ "$mode" == open ]]; then
    developer_dir=$(xcode-select -p)
    /usr/bin/open -a "$developer_dir/../.." "$work/ios/Rayfish.xcodeproj"
    exit 0
fi

xcodebuild -project "$work/ios/Rayfish.xcodeproj" -scheme Rayfish \
    -configuration Debug -destination "id=$IOS_DEVICE" \
    -derivedDataPath "$work/target/ios-device" -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$IOS_TEAM_ID" \
    RAYFISH_GIT_SHA="$RAYFISH_REV" build
echo "Built $work/target/ios-device/Build/Products/Debug-iphoneos/Rayfish.app"
echo 'Install and launch using Xcode, or xcrun devicectl device install app.'
