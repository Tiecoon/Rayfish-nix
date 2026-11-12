#!/usr/bin/env python3
"""Refresh the release, DMG checksums, flake lock, and Cargo vendor hash."""

import json
import os
from pathlib import Path
import re
import subprocess
import urllib.request

request = urllib.request.Request(
    "https://api.github.com/repos/rayfish/rayfish/releases/latest",
    headers={"Authorization": f"Bearer {os.environ['GH_TOKEN']}"}
    if os.environ.get("GH_TOKEN") else {},
)
with urllib.request.urlopen(request) as response:
    release = json.load(response)
tag = release["tag_name"]
if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
    raise SystemExit(f"Unexpected release tag: {tag}")
version = tag[1:]
assets = {asset["name"]: asset for asset in release["assets"]}
digest = assets[f"Rayfish-{version}-arm64.dmg"]["digest"]
if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest or ""):
    raise SystemExit("Missing SHA-256 for Apple Silicon DMG")

path = Path("flake.nix")
source = path.read_text()
source = re.sub(r"github:rayfish/rayfish/v[\d.]+", f"github:rayfish/rayfish/{tag}", source)
source = re.sub(r'version = "[\d.]+";', f'version = "{version}";', source)
source = re.sub(r'hash = "sha256:[0-9a-f]{64}";', f'hash = "{digest}";', source)
# Force the vendor fetcher to report the new content hash, even if nixpkgs
# changed its vendoring implementation without an upstream release.
source = re.sub(r'cargoHash = "[^"]+";', 'cargoHash = "sha256-' + "A" * 43 + '=";', source)
path.write_text(source)
subprocess.run(["nix", "flake", "update"], check=True)
result = subprocess.run(
    ["nix", "build", ".#cli.cargoDeps", "--no-link"],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
)
print(result.stdout)
match = re.search(r"got:\s+(sha256-[A-Za-z0-9+/]{43}=)", result.stdout)
if result.returncode == 0 or not match:
    raise SystemExit("Expected a Cargo vendor hash mismatch; inspect the build log")
path.write_text(re.sub(r'cargoHash = "[^"]+";', f'cargoHash = "{match[1]}";', source))
