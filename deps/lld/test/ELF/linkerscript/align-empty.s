# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:  abc : { } \
# RUN:  . = ALIGN(0x1000); \
# RUN:  foo : { *(foo) } \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t -shared
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s
# CHECK:      Sections:
# CHECK-NEXT: Idx Name          Size      Address
# CHECK-NEXT:   0               00000000 0000000000000000
# CHECK-NEXT:   1 foo           00000001 0000000000001000

        .section foo, "a"
        .byte 0
