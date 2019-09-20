# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { foo = bar; .bar : { *(.bar*) } }" > %t.script
# RUN: ld.lld %t.o --script %t.script -o %t.so -shared
# RUN: llvm-readobj --symbols %t.so | FileCheck %s

# CHECK:     Symbol {
# CHECK:      Name: bar
# CHECK-NEXT: Value: 0x[[VAL:.*]]
# CHECK:      Name: foo
# CHECK-NEXT: Value: 0x[[VAL]]

.section .bar.1, "a"
.quad 0

.section .bar.2, "a"
.quad 0
.global bar
bar:
