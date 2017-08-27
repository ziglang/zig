# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { foo : { *(.foo) CONSTRUCTORS } }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t.o

# RUN: llvm-objdump -section-headers %t1 | FileCheck %s
# CHECK:      Sections:
# CHECK-NEXT: Idx Name          Size
# CHECK-NEXT:   0               00000000
# CHECK-NEXT:   1 foo           00000001

.section foo, "a"
.byte 0
