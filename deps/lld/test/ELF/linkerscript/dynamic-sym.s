# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "_DYNAMIC = 0x123;" > %t.script
# RUN: ld.lld -T %t.script %t.o -shared -o %t.so
# RUN: llvm-readobj --symbols %t.so | FileCheck %s

# CHECK:      Symbol {
# CHECK:        Name: _DYNAMIC
# CHECK-NEXT:   Value: 0x123
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Local
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other [
# CHECK-NEXT:     STV_HIDDEN
# CHECK-NEXT:   ]
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }
