# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/copy-in-shared.s -o %t1.o
# RUN: echo "FOOVER { global: *; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t1.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
# RUN: ld.lld %t2.o %t.so -o %tout
# RUN: llvm-readobj -dyn-symbols %tout | FileCheck %s

# CHECK:      DynamicSymbols [
# CHECK:        Symbol {
# CHECK:          Name: foo@FOOVER
# CHECK-NEXT:     Value:
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: Object
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section: .bss.rel.ro
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.text
.global _start
_start:
movl $0, foo
