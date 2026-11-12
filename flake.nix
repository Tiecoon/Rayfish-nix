{
  description = "Rayfish for Linux and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rayfish = {
      url = "github:rayfish/rayfish/v0.5.16";
      flake = false;
    };
  };

  outputs = { nixpkgs, rayfish, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    in {
      packages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          version = "0.5.16";
          cli = pkgs.rustPlatform.buildRustPackage {
            pname = "rayfish";
            inherit version;
            src = rayfish;
            cargoHash = "sha256-5RKEXjlqObWmAO5OfOxEB4UC6+1OCWKR+GeMdMjYf8s=";
            cargoBuildFlags = [ "--package" "rayfish" "--bin" "ray" ];
            cargoTestFlags = [ "--package" "rayfish" "--bin" "ray" ];
            env.RUSTFLAGS = "-C target-cpu=native";
            env.NIX_CFLAGS_COMPILE = if pkgs.stdenv.hostPlatform.isAarch64
              then "-mcpu=native" else "-march=native";
            # CPU detection must happen on the machine that will run the binary.
            preferLocalBuild = true;
            allowSubstitutes = false;
            meta = {
              description = "Peer-to-peer mesh VPN over iroh";
              homepage = "https://github.com/rayfish/rayfish";
              license = pkgs.lib.licenses.mpl20;
              mainProgram = "ray";
              platforms = systems;
            };
          };
          gui = pkgs.stdenvNoCC.mkDerivation {
            pname = "rayfish-app";
            inherit version;
            src = pkgs.fetchurl {
              url = "https://github.com/rayfish/rayfish/releases/download/v${version}/Rayfish-${version}-arm64.dmg";
              hash = "sha256:17fdf0681e3f61c488755696722d65d2179055f812581eaa525603be4ed82523";
            };
            nativeBuildInputs = [ pkgs.undmg ];
            sourceRoot = ".";
            dontConfigure = true;
            dontBuild = true;
            # Preserve Apple's upstream code signatures, including nested helpers.
            dontFixup = true;
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/Applications" "$out/bin"
              cp -R Rayfish.app "$out/Applications/"
              ln -s "$out/Applications/Rayfish.app/Contents/MacOS/ray" "$out/bin/ray"
              runHook postInstall
            '';
            meta = cli.meta // {
              description = "Rayfish signed macOS app and bundled CLI";
              platforms = [ "aarch64-darwin" ];
            };
          };
        in {
          inherit cli;
          default = if pkgs.stdenv.hostPlatform.isDarwin then gui else cli;
        } // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin { inherit gui; });
    };
}
