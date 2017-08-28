# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "SECTIONS { .text : {*(.text)} foo : {*(foo)}}" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o -shared
# RUN: llvm-objdump --section-headers %t | FileCheck  %s

# Test the section order. This is a case where at least with libstdc++'s
# stable_sort we used to get a different result.

nop

.section foo, "a"
.byte 0

# CHECK: Id
# CHECK-NEXT: 0
# CHECK-NEXT: 1 .text
# CHECK-NEXT: 2 foo
# CHECK-NEXT: 3 .dynsym
# CHECK-NEXT: 4 .hash
# CHECK-NEXT: 5 .dynstr
# CHECK-NEXT: 6 .dynamic
# CHECK-NEXT: 7 .comment
# CHECK-NEXT: 8 .symtab
# CHECK-NEXT: 9 .shstrtab
# CHECK-NEXT: 10 .strtab
