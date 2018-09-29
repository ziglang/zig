// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: llvm-mc %p/Inputs/copy-rel-pie.s -o %t2.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t2.o -o %t2.so -shared
// RUN: not ld.lld %t.o %t2.so -o /dev/null -pie 2>&1 | FileCheck %s

// CHECK: can't create dynamic relocation R_X86_64_64 against symbol: bar in readonly segment; recompile object files with -fPIC or pass '-Wl,-z,notext' to allow text relocations in the output
// CHECK: >>> defined in {{.*}}.so
// CHECK: >>> referenced by {{.*}}.o:(.text+0x0)

// CHECK: can't create dynamic relocation R_X86_64_64 against symbol: foo in readonly segment; recompile object files with -fPIC or pass '-Wl,-z,notext' to allow text relocations in the output
// CHECK: >>> defined in {{.*}}.so
// CHECK: >>> referenced by {{.*}}.o:(.text+0x8)

.global _start
_start:
        .quad bar
        .quad foo
