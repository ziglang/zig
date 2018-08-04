// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: not ld.lld %t.o -o /dev/null -shared 2>&1 | FileCheck %s

// CHECK:  error: can't create dynamic relocation R_X86_64_SIZE64 against symbol: foo in readonly segment; recompile object files with -fPIC or pass '-Wl,-z,notext' to allow text relocations in the output

        .global foo
foo:
        .quad 42
        .size foo, 8

        .quad foo@SIZE
