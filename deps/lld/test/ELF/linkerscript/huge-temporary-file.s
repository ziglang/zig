# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { .text 0x2000 : {. = 0x10 ; *(.text) } }" > %t.script
# RUN: not ld.lld %t --script %t.script -o %t1

## This inputs previously created a 4gb temporarily file under 32 bit
## configuration. Issue was fixed. There is no clean way to check that from here.
## This testcase added for documentation purposes.

.globl _start
_start:
nop
