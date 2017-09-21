# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS {     \
# RUN:  .out : {            \
# RUN:   FILL(0x11111111)   \
# RUN:   . += 2;            \
# RUN:   *(.aaa)            \
# RUN:   . += 4;            \
# RUN:   *(.bbb)            \
# RUN:   . += 4;            \
# RUN:   FILL(0x22222222);  \
# RUN:   . += 4;            \
# RUN:  }                   \
# RUN: }; " > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-objdump -s %t | FileCheck %s

# CHECK:      Contents of section .out:
# CHECK-NEXT: 2222aa22 222222bb 22222222 22222222

.text
.globl _start
_start:

.section .aaa, "a"
.align 1
.byte 0xAA

.section .bbb, "a"
.align 1
.byte 0xBB
