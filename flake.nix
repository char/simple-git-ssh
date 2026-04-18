{
  description = "simple-ssh-git dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master"; # until nixos-unstable tracks zig 0.16
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
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
