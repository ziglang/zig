# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-objdump -D %t2 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-objdump -D %t2 | FileCheck -check-prefix=CHECK-BE %s

.text
.abiversion 2
.globl  _start
.p2align        4
.type   _start,@function

_start:
.Lfunc_begin0:
.Lfunc_gep0:
  lis   4, .Lfunc_gep0@ha
  addi  4, 4, .Lfunc_gep0@l
  # now r4 should contain the address of _start

  lis   5, .TOC.-.Lfunc_gep0@ha
  addi  5, 5, .TOC.-.Lfunc_gep0@l
  # now r5 should contain the offset s.t. r4 + r5 = TOC base

  # exit 55
  li    0, 1
  li    3, 55
  sc
.Lfunc_end0:
    .size   _start, .Lfunc_end0-.Lfunc_begin0

// CHECK: 10010000:       {{.*}}     lis 4, 4097
// CHECK-NEXT: 10010004:       {{.*}}     addi 4, 4, 0
// CHECK-NEXT: 10010008:       {{.*}}     lis 5, 2
// CHECK-NEXT: 1001000c:       {{.*}}     addi 5, 5, -32768
// CHECK: Disassembly of section .got:
// CHECK-NEXT: .got:
// CHECK-NEXT: 10020000:       00 80 02 10

// CHECK-BE: 10010000:       {{.*}}     lis 4, 4097
// CHECK-BE-NEXT: 10010004:       {{.*}}     addi 4, 4, 0
// CHECK-BE-NEXT: 10010008:       {{.*}}     lis 5, 2
// CHECK-BE-NEXT: 1001000c:       {{.*}}     addi 5, 5, -32768
// CHECK-BE: Disassembly of section .got:
// CHECK-BE-NEXT: .got:
// CHECK-BE-NEXT: 10020000:       00 00 00 00 {{.*}}
// CHECK-BE-NEXT: 10020004:       10 02 80 00 {{.*}}
