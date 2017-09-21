# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: echo "SECTIONS { A = . + 0x1; . += 0x1000; }" > %t.script
# RUN: ld.lld -shared %t1.o --script %t.script -o %t
# RUN: llvm-objdump -section-headers -t %t | FileCheck %s

# CHECK:       Sections:
# CHECK-NEXT:   Idx Name          Size      Address
# CHECK-NEXT:    0               00000000 0000000000000000
# CHECK-NEXT:    1 .text         00000000 0000000000001000

# CHECK: 0000000000000001         .text            00000000 A
