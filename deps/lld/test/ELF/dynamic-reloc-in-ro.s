// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: not ld.lld %t.o -o /dev/null -shared 2>&1 | FileCheck %s

// CHECK:      can't create dynamic relocation R_X86_64_64 against local symbol in readonly segment; recompile object files with -fPIC or pass '-Wl,-z,notext' to allow text relocations in the output
// CHECK-NEXT: >>> defined in {{.*}}.o
// CHECK-NEXT: >>> referenced by {{.*}}.o:(.text+0x0)

foo:
.quad foo
