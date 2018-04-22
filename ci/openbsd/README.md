# Openbsd CI scripts


## build_openbsd_image

This script is a self contained
[nix-shell](https://nixos.org/nix/manual/#sec-nix-shell) script.

It downloads the required dependencies and generates a qemu openbsd image
ready to run the CI script. Currently it uses the unreleased openbsd
snapshot because that is the version with llvm 6.0 . In the future this
should be changed to a stable release if possible. Until this is stable,
the CI script should just fetch this image from an s3 bucket.

## vmbuild

This script is what gets run on the openbsd virtual machine as the ci action.