{
  description = "Rayfish for Linux and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rayfish = {
      url = "github:rayfish/rayfish/v0.5.17";
      flake = false;
    };
  };

  outputs = { nixpkgs, rayfish, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      iosPkgs = import nixpkgs { system = "aarch64-darwin"; };
      iosBuild = iosPkgs.writeShellApplication {
        name = "rayfish-ios-build";
        runtimeInputs = with iosPkgs; [ rustup xcodegen python3 coreutils ];
        text = ''
          export RAYFISH_SOURCE=${rayfish}
          export RAYFISH_REV=${rayfish.rev}
          export RUSTUP_TOOLCHAIN=${iosPkgs.rustc.version}
          ${builtins.readFile ./scripts/ios-build.sh}
        '';
      };
    in {
      apps.aarch64-darwin.ios-build = {
        type = "app";
        program = "${iosBuild}/bin/rayfish-ios-build";
        meta.description = "Prepare and build Rayfish for iPhone using local Xcode";
      };
      packages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          version = "0.5.17";
          cli = pkgs.rustPlatform.buildRustPackage {
            pname = "rayfish";
            inherit version;
            src = rayfish;
            cargoHash = "sha256-Q7nAogmwIcN9CAYTGoXk0gQyxoX1iL4jre7ZNCPI5iA=";
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
              hash = "sha256:0dccd532dd9e422fbe21a463247108be78a090b960db472a75b1c0e1280cd37d";
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
