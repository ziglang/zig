# REQUIRES: x86
# This test checks that CallGraphSort ignores edges that would form "bad"
# clusters.

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "A C 1" > %t.call_graph
# RUN: echo "E B 4" >> %t.call_graph
# RUN: echo "C D 2" >> %t.call_graph
# RUN: echo "B D 1" >> %t.call_graph
# RUN: echo "F G 6" >> %t.call_graph
# RUN: echo "G H 5" >> %t.call_graph
# RUN: echo "H I 4" >> %t.call_graph
# RUN: ld.lld -e A %t --call-graph-ordering-file %t.call_graph -o %t2
# RUN: llvm-readobj -symbols %t2 | FileCheck %s

    .section    .text.A,"ax",@progbits
    .globl A
A:
    retq

    .section    .text.D,"ax",@progbits
D:
    .fill 1000, 1, 0

    .section    .text.E,"ax",@progbits
E:
    retq

    .section    .text.C,"ax",@progbits
C:
    retq

    .section    .text.B,"ax",@progbits
B:
    .fill 1000, 1, 0

    .section    .text.F,"ax",@progbits
F:
    .fill (1024 * 1024) - 1, 1, 0

    .section    .text.G,"ax",@progbits
G:
    retq

    .section    .text.H,"ax",@progbits
H:
    retq

    .section    .text.I,"ax",@progbits
I:
    .fill 13, 1, 0

# CHECK:          Name: B
# CHECK-NEXT:     Value: 0x201011
# CHECK:          Name: C
# CHECK-NEXT:     Value: 0x20100F
# CHECK:          Name: D
# CHECK-NEXT:     Value: 0x2013F9
# CHECK:          Name: E
# CHECK-NEXT:     Value: 0x201010
# CHECK:          Name: F
# CHECK-NEXT:     Value: 0x2017E1
# CHECK:          Name: G
# CHECK-NEXT:     Value: 0x3017E0
# CHECK:          Name: H
# CHECK-NEXT:     Value: 0x201000
# CHECK:          Name: I
# CHECK-NEXT:     Value: 0x201001
# CHECK:          Name: A
# CHECK-NEXT:     Value: 0x20100E
