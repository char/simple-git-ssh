{
  description = "simple-git-ssh dev shell & package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      packages = forAllSystems (pkgs: let
        shlex = pkgs.fetchFromGitHub {
          owner = "char";
          repo = "shlex";
          rev = "293b7c4bdc3b6c9a3195d226f0d8e92bf4516f96";
          hash = "sha256-aL5AJYVjnmvu8BJMD3f1z99e4MGJgNkUrOidWhr27NE=";
        };
      in {
        default = pkgs.stdenv.mkDerivation {
          pname = "simple-git-ssh";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.zig ];

          postPatch = ''
            mkdir -p zig-pkg
            ln -s ${shlex} zig-pkg/shlex-0.1.1-O1DEI5oDAQARcXkYasXdAAsR0riDfb-1_riTtx0vemxN
          '';
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.zig
            pkgs.git
          ];
        };
      });
    };
}
