# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "A B 100" > %t.call_graph
# RUN: echo "A C 40" >> %t.call_graph
# RUN: echo "C D 61" >> %t.call_graph
# RUN: ld.lld -e A %t --call-graph-ordering-file %t.call_graph -o %t.out -icf=all
# RUN: llvm-readobj --symbols %t.out | FileCheck %s
# RUN: ld.lld -e A %t --call-graph-ordering-file %t.call_graph -o %t2.out
# RUN: llvm-readobj --symbols %t2.out | FileCheck %s --check-prefix=NOICF

    .section    .text.D,"ax",@progbits
    .globl  D
D:
    mov $60, %rax
    retq

    .section    .text.C,"ax",@progbits
    .globl  C
C:
    mov $60, %rax
    retq

    .section    .text.B,"ax",@progbits
    .globl  B
B:
    mov $2, %rax
    retq

    .section    .text.A,"ax",@progbits
    .globl  A
A:
    mov $42, %rax
    retq

# CHECK:          Name: A
# CHECK-NEXT:     Value: 0x201000
# CHECK:          Name: B
# CHECK-NEXT:     Value: 0x201010
# CHECK:          Name: C
# CHECK-NEXT:     Value: 0x201008
# CHECK:          Name: D
# CHECK-NEXT:     Value: 0x201008

# NOICF:          Name: A
# NOICF-NEXT:     Value: 0x201000
# NOICF:          Name: B
# NOICF-NEXT:     Value: 0x201008
# NOICF:          Name: C
# NOICF-NEXT:     Value: 0x201010
# NOICF:          Name: D
# NOICF-NEXT:     Value: 0x201018
