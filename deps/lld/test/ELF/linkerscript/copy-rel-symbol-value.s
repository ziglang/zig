# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/copy-rel-symbol-value.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: echo "SECTIONS { . = . + SIZEOF_HEADERS; foo = bar; }" > %t.script
# RUN: ld.lld %t.o %t2.so --script %t.script -o %t
# RUN: llvm-readobj -t %t | FileCheck %s

# CHECK:      Name: bar
# CHECK-NEXT: Value: 0x[[VAL:.*]]
# CHECK-NEXT: Size: 8
# CHECK-NEXT: Binding: Global
# CHECK-NEXT: Type: Object
# CHECK-NEXT: Other: 0
# CHECK-NEXT: Section: .bss.rel.ro

# CHECK:      Name: foo
# CHECK-NEXT: Value: 0x[[VAL]]
# CHECK-NEXT: Size:
# CHECK-NEXT: Binding: Global
# CHECK-NEXT: Type:
# CHECK-NEXT: Other: 0
# CHECK-NEXT: Section: .bss.rel.ro

.global _start
_start:
.quad bar
