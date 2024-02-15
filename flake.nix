{
  # This flake's main purpose is to aid the development of zig
  # To use zig in your project's flake instead take a look at:
  # - zig from nixpkgs
  # - https://github.com/Cloudef/zig2nix
  # - https://github.com/mitchellh/zig-overlay
  #
  # General usage:
  #   nix develop
  #   mkdir build
  #   cd build
  #   cmake $cmakeFlags ..
  #   make -j8
  #   ... do whatever you wanted to do ...
  #
  # Other stuff provided by this flake are purely for convenience
  description = "zig flake for compiler development";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, ... }:
  (flake-utils.lib.eachDefaultSystem (system: let
    pkgs = self.inputs.nixpkgs.outputs.legacyPackages.${system};
  in rec {
    # nix run .#zig-llvm
    # nix build .#zig-llvm
    packages.zig-llvm = pkgs.callPackage ./nix/llvm.nix {};

    # nix run .#zig-stage2
    # nix build .#zig-stage2
    packages.zig-stage2 = pkgs.callPackage ./nix/stage2.nix {};

    # nix run
    # nix build
    packages.default = packages.zig-llvm;

    # The devShells do not give you a zig in the PATH
    # They give you the environment to incrementally build zig instead so you can hack on it

    # You can access default CMake flags with $cmakeFlags env var
    # nix develop .#zig-llvm
    devShells.zig-llvm = packages.zig-llvm;

    # Requires only a C compiler so `nix run .#zig-stage2` might be more useful
    # nix develop .#zig-stage2
    devShells.zig-stage2 = packages.zig-stage2;

    # nix develop
    devShells.default = devShells.zig-llvm;
  }));
}
