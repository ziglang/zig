{
  description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs:
    inputs.utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in {
      packages.default = pkgs.zig-master;
    })
    // {
      overlays.default = final: prev: {
        zig-master = prev.zig.overrideAttrs (attrs: {
          version = "master";
          src = ../.;

          nativeBuildInputs = with prev; [
            cmake
            llvmPackages_14.llvm.dev
          ];
          buildInputs = with prev;
            [
              libxml2
              zlib
            ]
            ++ (with llvmPackages_14; [
              libclang
              lld
              llvm
            ]);

          cmakeFlags =
            attrs.cmakeFlags
            ++ [
              "-DZIG_STATIC_ZLIB=ON"
            ];
        });
      };
    };
}
