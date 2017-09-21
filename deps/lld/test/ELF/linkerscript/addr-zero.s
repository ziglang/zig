# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { foo = ADDR(.text) - ABSOLUTE(ADDR(.text)); };" > %t.script
# RUN: ld.lld -o %t.so --script %t.script %t.o -shared
# RUN: llvm-readobj --symbols %t.so | FileCheck %s

# Test that the script creates a non absolute symbol with value
# 0 I.E., a symbol that refers to the load address.

# CHECK:      Symbol {
# CHECK:        Name: foo
# CHECK-NEXT:   Value: 0x0
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: .text
# CHECK-NEXT: }
