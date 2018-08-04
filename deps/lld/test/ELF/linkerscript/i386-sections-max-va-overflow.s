# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t.o

# RUN: echo "SECTIONS { . = 0xfffffff1;" > %t.script
# RUN: echo "           .bar : { *(.bar*) } }" >> %t.script
# RUN: not ld.lld -o /dev/null --script %t.script %t.o 2>&1 | FileCheck %s -check-prefix=ERR

## .bar section has data in [0xfffffff1, 0xfffffff1 + 0x10] == [0xffffff1, 0x1]. 
## Check we can catch this overflow.
# ERR: error: section .bar at 0xFFFFFFF1 of size 0x10 exceeds available address space

.section .bar,"ax",@progbits
.zero 0x10
