# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: ld.lld -o %t.out %t --oformat binary
# RUN: od -t x1 -v %t.out | FileCheck %s
# CHECK: 000000 90 11 22 00 00 00 00 00
# CHECK-NOT: 00000010

## Check case when linkerscript is used.
# RUN: echo "SECTIONS { . = 0x1000; }" > %t.script
# RUN: ld.lld -o %t2.out --script %t.script %t --oformat binary
# RUN: od -t x1 -v %t2.out | FileCheck %s

# RUN: echo "SECTIONS { }" > %t.script
# RUN: ld.lld -o %t2.out --script %t.script %t --oformat binary
# RUN: od -t x1 -v %t2.out | FileCheck %s

# RUN: not ld.lld -o %t3.out %t --oformat foo 2>&1 \
# RUN:   | FileCheck %s --check-prefix ERR
# ERR: unknown --oformat value: foo

.text
.align 4
.globl _start
_start:
 nop

.section        .mysec.1,"ax"
.byte   0x11

.section        .mysec.2,"ax"
.byte   0x22
