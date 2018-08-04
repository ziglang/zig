# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t
# RUN: ld.lld -Ttext 0x7c00 %t -o %t2
# RUN: llvm-objdump -s %t2 | FileCheck %s

# CHECK:       Contents of section .text:
# CHECK-NEXT:  7c00 b800ff

.code16
.global _start
_start:
 movw $_start+0x8300,%ax
