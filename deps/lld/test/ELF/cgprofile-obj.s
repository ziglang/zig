# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld -e A %t.o -o %t
# RUN: llvm-nm --no-sort %t | FileCheck %s
# RUN: ld.lld --no-call-graph-profile-sort -e A %t.o -o %t
# RUN: llvm-nm --no-sort %t | FileCheck %s --check-prefix=NO-CG

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

# CHECK: 0000000000201003 t D
# CHECK: 0000000000201000 T A
# CHECK: 0000000000201001 T B
# CHECK: 0000000000201002 T C

# NO-CG: 0000000000201000 t D
# NO-CG: 0000000000201003 T A
# NO-CG: 0000000000201002 T B
# NO-CG: 0000000000201001 T C
