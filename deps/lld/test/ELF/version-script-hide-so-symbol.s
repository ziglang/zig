# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t2.so
# RUN: echo "{ local: *; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o %t2.so -o %t.so
# RUN: llvm-readobj -dyn-symbols %t.so | FileCheck %s

# The symbol foo must be hidden. This matches bfd and gold and is
# required to make it possible for a c++ library to hide its own
# operator delete.

# CHECK:      DynamicSymbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: @ (0)
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other: 0
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }
# CHECK-NEXT: ]

        .global foo
foo:
	nop

