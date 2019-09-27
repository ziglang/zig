# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "A B 5" > %t.call_graph
# RUN: echo "B C 50" >> %t.call_graph
# RUN: echo "C D 40" >> %t.call_graph
# RUN: echo "D B 10" >> %t.call_graph
# RUN: ld.lld -e A %t --call-graph-ordering-file %t.call_graph -o %t2 --print-symbol-order=%t3
# RUN: ld.lld -e A %t --symbol-ordering-file %t3 -o %t2
# RUN: llvm-readobj --symbols %t2 | FileCheck %s

# CHECK:      Name: A
# CHECK-NEXT: Value: 0x201003
# CHECK:      Name: B
# CHECK-NEXT: Value: 0x201000
# CHECK:      Name: C
# CHECK-NEXT: Value: 0x201001
# CHECK:      Name: D
# CHECK-NEXT: Value: 0x201002

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



