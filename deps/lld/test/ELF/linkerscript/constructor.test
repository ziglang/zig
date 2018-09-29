# REQUIRES: x86
# RUN: echo '.section foo, "a"; .byte 0' \
# RUN:   | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t.o
# RUN: ld.lld -o %t1 --script %s %t.o

# RUN: llvm-objdump -section-headers %t1 | FileCheck %s
# CHECK:      Sections:
# CHECK-NEXT: Idx Name          Size
# CHECK-NEXT:   0               00000000
# CHECK-NEXT:   1 foo           00000001

SECTIONS {
  foo : {
    *(.foo)
    CONSTRUCTORS
  }
}
