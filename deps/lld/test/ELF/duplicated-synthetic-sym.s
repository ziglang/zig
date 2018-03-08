// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: cd %S
// RUN: not ld.lld %t.o --format=binary duplicated-synthetic-sym.s -o %t.elf 2>&1 | FileCheck %s
// RUN: not ld.lld %t.o --format binary duplicated-synthetic-sym.s -o %t.elf 2>&1 | FileCheck %s

// CHECK: duplicate symbol: _binary_duplicated_synthetic_sym_s_start
// CHECK: defined at <internal>:(.data+0x0)

    .globl  _binary_duplicated_synthetic_sym_s_start
_binary_duplicated_synthetic_sym_s_start:
    .long   0
