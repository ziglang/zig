# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS { \
# RUN:   . = SIZEOF_HEADERS; \
# RUN:   .text : { *(.text) } \
# RUN:   .foo : {foo1 = .;  *(.foo.*) foo2 = .;  *(.bar) foo3 = .;} \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t -shared
# RUN: llvm-readobj -t %t1 | FileCheck %s

# CHECK:      Name: foo1
# CHECK-NEXT: Value: 0x228

# CHECK:      Name: foo2
# CHECK-NEXT: Value: 0x230

# CHECK:      Name: foo3
# CHECK-NEXT: Value: 0x234

.section .foo.1,"a"
 .long 1

.section .foo.2,"aw"
 .long 2

 .section .bar,"aw"
 .long 3
