// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o /dev/null -shared
// Allow user defined __init_array_start. This is used by musl because of the
// the bfd linker not handling these properly. We always create them as
// hidden, musl should not have problems with lld.

        .hidden __init_array_start
        .globl  __init_array_start
__init_array_start:
        .zero   8
