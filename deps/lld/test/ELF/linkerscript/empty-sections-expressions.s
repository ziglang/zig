# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

## We remove empty sections that do not reference symbols in address,
## LMA, align and subalign expressions. Here we check that.

# RUN: echo "SECTIONS { .debug_info 0 : { *(.debug_info) } }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-objdump -section-headers %t | FileCheck %s
# CHECK-NOT: .debug_info

# RUN: echo "SECTIONS { .debug_info foo : { *(.debug_info) } }" > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %t.o
# RUN: llvm-objdump -section-headers %t2 | FileCheck %s --check-prefix=SEC
# SEC: .debug_info

.globl foo
foo:
