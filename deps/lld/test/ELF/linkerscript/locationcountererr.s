# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS {" > %t.script
# RUN: echo ".text 0x2000 : {. = 0x10 ; *(.text) } }" >> %t.script
# RUN: not ld.lld %t --script %t.script -o %t1 2>&1 | FileCheck %s
# CHECK: {{.*}}.script:2: unable to move location counter backward for: .text

.globl _start
_start:
nop
