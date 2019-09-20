// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld -e A %t.o --no-call-graph-profile-sort -o %t
// RUN: llvm-nm --numeric-sort %t | FileCheck %s --check-prefix=NO_ORDERING
// NO_ORDERING:         0000000000201000 t D
// NO_ORDERING-NEXT:    0000000000201001 T C
// NO_ORDERING-NEXT:    0000000000201002 T B
// NO_ORDERING-NEXT:    0000000000201003 T A

// RUN: ld.lld -e A %t.o -o %t
// RUN: llvm-nm --numeric-sort %t | FileCheck %s --check-prefix=CALL_GRAPH
// CALL_GRAPH:		0000000000201000 T A
// CALL_GRAPH-NEXT:	0000000000201000 t Aa
// CALL_GRAPH-NEXT:	0000000000201001 T B
// CALL_GRAPH-NEXT:	0000000000201002 T C
// CALL_GRAPH-NEXT:	0000000000201003 t D

// RUN: rm -f %t.symbol_order
// RUN: echo "C" >> %t.symbol_order
// RUN: echo "B" >> %t.symbol_order
// RUN: echo "D" >> %t.symbol_order
// RUN: echo "A" >> %t.symbol_order

// RUN: ld.lld -e A %t.o --symbol-ordering-file %t.symbol_order -o %t
// RUN: llvm-nm --numeric-sort %t | FileCheck %s --check-prefix=SYMBOL_ORDER
// SYMBOL_ORDER:	0000000000201000 T C
// SYMBOL_ORDER-NEXT:	0000000000201001 T B
// SYMBOL_ORDER-NEXT:	0000000000201002 t D
// SYMBOL_ORDER-NEXT:	0000000000201003 T A

// RUN: rm -f %t.call_graph
// RUN: echo "A B 5" > %t.call_graph
// RUN: echo "B C 50" >> %t.call_graph
// RUN: echo "C D 40" >> %t.call_graph
// RUN: echo "D B 10" >> %t.call_graph

// RUN: not ld.lld -e A %t.o --symbol-ordering-file %t.symbol_order --call-graph-ordering-file %t.call_graph -o %t 2>&1 | FileCheck %s
// RUN: not ld.lld -e A %t.o --call-graph-ordering-file %t.call_graph --symbol-ordering-file %t.symbol_order -o %t 2>&1 | FileCheck %s
// CHECK: error: --symbol-ordering-file and --call-graph-order-file may not be used together

    .section    .text.D,"ax",@progbits
D:
    retq

    .section    .text.C,"ax",@progbits
    .globl  C
C:
    retq

    .section    .text.B,"ax",@progbits
    .globl  B
B:
    retq

    .section    .text.A,"ax",@progbits
    .globl  A
A:
Aa:
    retq

    .cg_profile A, B, 10
    .cg_profile A, B, 10
    .cg_profile Aa, B, 80
    .cg_profile A, C, 40
    .cg_profile B, C, 30
    .cg_profile C, D, 90
