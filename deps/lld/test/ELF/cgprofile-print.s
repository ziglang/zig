# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "A B 5" > %t.call_graph
# RUN: echo "B C 50" >> %t.call_graph
# RUN: echo "C D 40" >> %t.call_graph
# RUN: echo "D B 10" >> %t.call_graph
# RUN: ld.lld -e A %t --call-graph-ordering-file %t.call_graph -o %t2 --print-symbol-order=%t3
# RUN: FileCheck %s --input-file %t3

# CHECK: B
# CHECK-NEXT: C
# CHECK-NEXT: D
# CHECK-NEXT: A

.section    .text.A,"ax",@progbits
.globl  A
A:
 nop

.section    .text.B,"ax",@progbits
.globl  B
B:
 nop

.section    .text.C,"ax",@progbits
.globl  C
C:
 nop

.section    .text.D,"ax",@progbits
.globl  D
D:
 nop



