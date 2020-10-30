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



apt-get -y update
rm -rf /usr/local/*
apt-get -y install software-properties-common curl wget gnupg gnupg1 gnupg2 git

export DEBIAN_FRONTEND=noninteractive
sh -c 'echo "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-11 main" >> /etc/apt/sources.list'
wget -O - http://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
add-apt-repository -y ppa:ubuntu-toolchain-r/test
apt-get -y update
apt-get remove -y llvm-*
apt-get install -y libxml2-dev libclang-11-dev llvm-11 llvm-11-dev liblld-11-dev cmake s3cmd gcc-7 g++-7 ninja-build tidy

export DEBIAN_FRONTEND=noninteractive
# Make the `zig version` number consistent.
# This will affect the cmake command below.
git config core.abbrev 9
export CC=gcc-7
export CXX=g++-7
rm -rf /app/build
mkdir -p /app/build
cd /app/build
cmake .. -DCMAKE_BUILD_TYPE=Release -GNinja
ninja install

export DEBIAN_FRONTEND=noninteractive
cd /app
./zig help
