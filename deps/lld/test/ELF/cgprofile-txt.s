# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld -e A %t -o %t2
# RUN: llvm-readobj --symbols %t2 | FileCheck %s --check-prefix=NOSORT

# RUN: echo "A B 10" > %t.call_graph
# RUN: echo "A B 10" >> %t.call_graph
# RUN: echo "Aa B 80" >> %t.call_graph
# RUN: echo "A C 40" >> %t.call_graph
# RUN: echo "B C 30" >> %t.call_graph
# RUN: echo "C D 90" >> %t.call_graph
# RUN: echo "PP TS 100" >> %t.call_graph
# RUN: echo "_init2 _init 24567837" >> %t.call_graph
# RUN: echo "TS QC 9001" >> %t.call_graph
# RUN: echo "TooManyPreds0 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds1 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds2 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds3 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds4 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds5 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds6 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds7 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds8 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds9 TooManyPreds 10" >> %t.call_graph
# RUN: echo "TooManyPreds10 TooManyPreds 11" >> %t.call_graph
# RUN: ld.lld -e A %t --call-graph-ordering-file %t.call_graph -o %t2
# RUN: llvm-readobj --symbols %t2 | FileCheck %s

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

    .section    .ponies,"ax",@progbits,unique,1
    .globl TS
TS:
    retq

    .section    .ponies,"ax",@progbits,unique,2
    .globl PP
PP:
    retq

    .section    .other,"ax",@progbits,unique,1
    .globl QC
QC:
    retq

    .section    .other,"ax",@progbits,unique,2
    .globl GB
GB:
    retq

    .section    .init,"ax",@progbits,unique,1
    .globl _init
_init:
    retq

    .section    .init,"ax",@progbits,unique,2
    .globl _init2
_init2:
    retq

    .section    .text.TooManyPreds,"ax",@progbits
TooManyPreds:
    retq
	retq
	retq
	retq
	retq
	retq
	retq
	retq
	retq
	retq

    .section    .text.TooManyPreds0,"ax",@progbits
TooManyPreds0:
    retq

    .section    .text.TooManyPreds1,"ax",@progbits
TooManyPreds1:
    retq

    .section    .text.TooManyPreds2,"ax",@progbits
TooManyPreds2:
    retq

    .section    .text.TooManyPreds3,"ax",@progbits
TooManyPreds3:
    retq

    .section    .text.TooManyPreds4,"ax",@progbits
TooManyPreds4:
    retq

    .section    .text.TooManyPreds5,"ax",@progbits
TooManyPreds5:
    retq

    .section    .text.TooManyPreds6,"ax",@progbits
TooManyPreds6:
    retq

    .section    .text.TooManyPreds7,"ax",@progbits
TooManyPreds7:
    retq

    .section    .text.TooManyPreds8,"ax",@progbits
TooManyPreds8:
    retq

    .section    .text.TooManyPreds9,"ax",@progbits
TooManyPreds9:
    retq

    .section    .text.TooManyPreds10,"ax",@progbits
TooManyPreds10:
    retq

# CHECK:          Name: D
# CHECK-NEXT:     Value: 0x201003
# CHECK:          Name: TooManyPreds
# CHECK-NEXT:     Value: 0x201004
# CHECK:          Name: TooManyPreds10
# CHECK-NEXT:     Value: 0x201018
# CHECK:          Name: A
# CHECK-NEXT:     Value: 0x201000
# CHECK:          Name: B
# CHECK-NEXT:     Value: 0x201001
# CHECK:          Name: C
# CHECK-NEXT:     Value: 0x201002
# CHECK:          Name: GB
# CHECK-NEXT:     Value: 0x20101F
# CHECK:          Name: PP
# CHECK-NEXT:     Value: 0x20101C
# CHECK:          Name: QC
# CHECK-NEXT:     Value: 0x20101E
# CHECK:          Name: TS
# CHECK-NEXT:     Value: 0x20101D
# CHECK:          Name: _init
# CHECK-NEXT:     Value: 0x201020
# CHECK:          Name: _init2
# CHECK-NEXT:     Value: 0x201021

# NOSORT:          Name: D
# NOSORT-NEXT:     Value: 0x201000
# NOSORT:          Name: TooManyPreds
# NOSORT-NEXT:     Value: 0x201004
# NOSORT:          Name: TooManyPreds10
# NOSORT-NEXT:     Value: 0x201018
# NOSORT:          Name: A
# NOSORT-NEXT:     Value: 0x201003
# NOSORT:          Name: B
# NOSORT-NEXT:     Value: 0x201002
# NOSORT:          Name: C
# NOSORT-NEXT:     Value: 0x201001
# NOSORT:          Name: GB
# NOSORT-NEXT:     Value: 0x20101C
# NOSORT:          Name: PP
# NOSORT-NEXT:     Value: 0x20101A
# NOSORT:          Name: QC
# NOSORT-NEXT:     Value: 0x20101B
# NOSORT:          Name: TS
# NOSORT-NEXT:     Value: 0x201019
# NOSORT:          Name: _init
# NOSORT-NEXT:     Value: 0x20101D
# NOSORT:          Name: _init2
# NOSORT-NEXT:     Value: 0x20101E
