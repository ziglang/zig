# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux-gnu %s -o %t1.o

# RUN: ld.lld -Ttext=0x0 %t1.o -o %t.out
# RUN: llvm-objdump -s -t %t.out | FileCheck %s
# CHECK:      Contents of section .text:
# CHECK-NEXT:  0000 020100
## 0x3 + addend(-1) = 0x02
## 0x3 + addend(-2) = 0x0100
# CHECK: SYMBOL TABLE:
# CHECK: 00000003 .und

.byte  und-1
.short und-2

.section .und, "ax"
und:
