// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/shared-ppc64.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld %t.o %t2.so -o %t
// RUN: llvm-objdump -d %t | FileCheck %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/shared-ppc64.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld %t.o %t2.so -o %t
// RUN: llvm-objdump -d %t | FileCheck %s

// CHECK:      Disassembly of section .text:
// CHECK-NEXT: __plt_foo:
// CHECK-NEXT:      std 2, 24(1)
// CHECK-NEXT:      addis 12, 2, 0
// CHECK-NEXT:      ld 12, 32560(12)
// CHECK-NEXT:      mtctr 12
// CHECK-NEXT:      bctr


// CHECK:            _start:
// CHECK:            bl .+67108824
        .text
        .abiversion 2
        .globl  _start
        .p2align        4
        .type   _start,@function
_start:
.Lfunc_begin0:
.Lfunc_gep0:
  addis 2, 12, .TOC.-.Lfunc_gep0@ha
  addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
  .localentry     _start, .Lfunc_lep0-.Lfunc_gep0
  bl foo
  nop
  li 0, 1
  sc
  .size _start, .-.Lfunc_begin0
