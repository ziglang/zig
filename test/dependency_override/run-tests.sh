#!/bin/sh

ZIG=$1

rm -r local-cache global-cache .zig-cache
cp -r cache-with-good-pkgs local-cache
cp -r cache-with-bad-pkgs global-cache
$ZIG build test --global-cache-dir global-cache --cache-dir local-cache && \
$ZIG build test --cache-dir local-cache && \
$ZIG build test --system cache-with-good-pkgs/p
