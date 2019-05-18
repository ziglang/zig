#!/usr/bin/env bash
# Generate all the glibc stubs needed for cross-compiling
if [ $# -ne 1 ]; then
    echo "usage: $0 path_to_glibc_root"
    exit 1
fi

glibc_root=$1
libs=( c m dl rt pthread )
archs=( x86_64/64 i386 aarch64 )
ver=GLIBC_2.17

for arch in "${archs[@]}"; do
    _arch=${arch/\/64/}
    mkdir -p glibc_stubs/${_arch}
    for lib in "${libs[@]}"; do
        ./gen_glibc_stubs.py glibc_stubs/${_arch}/${lib} ${ver} \
            "${glibc_root}/sysdeps/generic/lib${lib}.abilist" \
            "${glibc_root}/sysdeps/unix/sysv/linux/${arch}/lib${lib}.abilist"
    done
done
