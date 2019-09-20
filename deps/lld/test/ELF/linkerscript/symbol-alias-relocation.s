# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "aliasto__text = __text; SECTIONS { .text 0x1000 : { __text = . ; *(.text) } }" > %t.script
# RUN: ld.lld -pie -o %t --script %t.script %t.o
# RUN: llvm-readobj --symbols %t | FileCheck %s

## Check that alias 'aliasto__text' has the correct value.
## (It should belong to the section .text and point to it's start).

# CHECK:      Symbol {
# CHECK:        Name: __text
# CHECK-NEXT:   Value: 0x1000
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: .text
# CHECK-NEXT: }

# CHECK:      Symbol {
# CHECK:        Name: aliasto__text
# CHECK-NEXT:   Value: 0x1000
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: .text
# CHECK-NEXT: }

.text
.globl _start
.type _start, %function
_start:
.globl aliasto__text
   call __text
   call aliasto__text
