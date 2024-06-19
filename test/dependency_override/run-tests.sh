#!/bin/sh

ZIG=$1

if [ -d local-cache ]; then rm local-cache; fi
if [ -d global-cache ]; then rm global-cache; fi

cp -r cache-with-good-pkgs local-cache
cp -r cache-with-bad-pkgs global-cache

$ZIG build test --global-cache-dir global-cache --cache-dir local-cache && \
$ZIG build test --cache-dir local-cache && \
$ZIG build test --system cache-with-good-pkgs/p --cache-dir global-cache

rm -r local-cache global-cache
cp -r cache-with-bad-pkgs local-cache
cp -r cache-with-good-pkgs global-cache

$ZIG build test --global-cache-dir global-cache --cache-dir local-cache
if [ $? -eq 0 ]; then exit 1; fi
$ZIG build test --cache-dir local-cache
if [ $? -eq 0 ]; then exit 1; fi

rm -r local-cache global-cache
