# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS { .foo 0 : {*(foo)} }" > %t.script
# RUN: ld.lld --hash-style=sysv -o %t --script %t.script %t.o -shared
# RUN: llvm-readelf -S -l %t | FileCheck %s

# Test that we create all necessary PT_LOAD. We use to stop at the first
# non-alloc, causing us to not create PT_LOAD for linker generated sections.

# CHECK: Program Headers:
# CHECK-NEXT:  Type
# CHECK-NEXT:  LOAD {{.*}} R E
# CHECK-NEXT:  LOAD {{.*}} RW

# CHECK:      Section to Segment mapping:
# CHECK-NEXT:  Segment Sections...
# CHECK-NEXT:   00     .dynsym .hash .dynstr .text
# CHECK-NEXT:   01     .dynamic

nop
.section foo
.quad 0
