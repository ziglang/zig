# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux-gnu %s -o %t1.o

# RUN: ld.lld %t1.o -o %t.out
# RUN: llvm-objdump -s -t %t.out | FileCheck %s
# CHECK:      Contents of section .text:
# CHECK-NEXT:  11000 020000
## 0x11003 - 0x11000 + addend(-1) = 0x02
## 0x11003 - 0x11001 + addend(-2) = 0x0000
# CHECK: SYMBOL TABLE:
# CHECK: 00011003 .und

.byte  und-.-1
.short und-.-2

.section .und, "ax"
und:
