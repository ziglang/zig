# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --gc-sections %t.o -o %t
# RUN: llvm-objdump -section-headers %t | FileCheck  %s

# CHECK:      1 .foo1
# CHECK-NEXT:   bar1
# CHECK-NEXT:   .zed1
# CHECK-NEXT:   .text
# CHECK-NEXT:   .comment
# CHECK-NEXT:   .symtab
# CHECK-NEXT:   .shstrtab
# CHECK-NEXT:   .strtab

.global _start
_start:
.quad .foo1

.section .foo1,"a"
.quad 0

.section .foo2,"a"
.quad 0

.section bar1,"ao",@progbits,.foo1
.quad .zed1
.quad .foo1

.section bar2,"ao",@progbits,.foo2
.quad .zed2
.quad .foo2

.section .zed1,"a"
.quad 0

.section .zed2,"a"
.quad 0
