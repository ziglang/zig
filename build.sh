#!/bin/sh
set -e
if [ "x$1" != x--debug ]; then
    cmake -GNinja -S. -Bbuild -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_C_COMPILER:FILEPATH=clang -DCMAKE_CXX_COMPILER:FILEPATH=clang++ -DZIG_NO_LIB:BOOL=ON
    cmake --build build
    cmake --install build
fi
build/stage3/bin/zig build -p debug -Dno-lib -Denable-stage1 -Denable-llvm -freference-trace
#build/stage3/bin/zig build -p only-c -Dno-lib -Donly-c
