# REQUIRES: arm
# RUN: llvm-mc -filetype=obj -triple=armv7-unknown-linux %s -o %t.o

# RUN: echo ordered > %t_order.txt
# RUN: ld.lld --symbol-ordering-file %t_order.txt %t.o -o %t2.out
# RUN: llvm-nm -n %t2.out | FileCheck %s

# CHECK: unordered1
# CHECK-NEXT: unordered2
# CHECK-NEXT: unordered3
# CHECK-NEXT: ordered
# CHECK-NEXT: unordered4

.section .foo,"ax",%progbits,unique,1
unordered1:
.zero 1

.section .foo,"ax",%progbits,unique,2
unordered2:
.zero 1

.section .foo,"ax",%progbits,unique,3
unordered3:
.zero 2

.section .foo,"ax",%progbits,unique,4
unordered4:
.zero 4

.section .foo,"ax",%progbits,unique,5
ordered:
.zero 1
