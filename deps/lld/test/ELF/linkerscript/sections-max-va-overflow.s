# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "SECTIONS { . = 0xfffffffffffffff1;" > %t.script
# RUN: echo "           .bar : { *(.bar*) } }" >> %t.script
# RUN: not ld.lld -o /dev/null --script %t.script %t.o 2>&1 | FileCheck %s -check-prefix=ERR

## .bar section has data in [0xfffffffffffffff1, 0xfffffffffffffff1 + 0x10] ==
## [0xfffffffffffffff1, 0x1]. Check we can catch this overflow.
# ERR: error: section .bar at 0xFFFFFFFFFFFFFFF1 of size 0x10 exceeds available address space

.section .bar,"ax",@progbits
.zero 0x10
