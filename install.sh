#!/usr/bin/env bash
if test "$BASH" = "" || "$BASH" -uc "a=();true \"\${a[@]}\"" 2>/dev/null; then
    # Bash 4.4, Zsh
    set -euo pipefail
else
    # Bash 4.3 and older chokes on empty arrays with set -u.
    set -eo pipefail
fi
shopt -s nullglob globstar
export DEBIAN_FRONTEND=noninteractive


export DEBIAN_FRONTEND=noninteractive
# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9
export CC=gcc-7
export CXX=g++-7
rm -rf /app/build \
mkdir -p /app/build
cd /app/build
cmake ..
make install