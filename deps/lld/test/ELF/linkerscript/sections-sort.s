# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "SECTIONS { .text : {*(.text)} foo : {*(foo)}}" > %t.script
# RUN: ld.lld --hash-style=sysv -o %t --script %t.script %t.o -shared
# RUN: llvm-objdump --section-headers %t | FileCheck  %s

# Test the section order. This is a case where at least with libstdc++'s
# stable_sort we used to get a different result.

nop

.section foo, "a"
.byte 0

# CHECK: Idx
# CHECK-NEXT: 0
# CHECK-NEXT: 1 .text
# CHECK-NEXT: 2 .dynsym
# CHECK-NEXT: 3 .hash
# CHECK-NEXT: 4 .dynstr
# CHECK-NEXT: 5 foo
# CHECK-NEXT: 6 .dynamic
# CHECK-NEXT: 7 .comment
# CHECK-NEXT: 8 .symtab
# CHECK-NEXT: 9 .shstrtab
# CHECK-NEXT: 10 .strtab
