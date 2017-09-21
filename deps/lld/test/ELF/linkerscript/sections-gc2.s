# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:         used_in_reloc : { *(used_in_reloc) } \
# RUN:         used_in_script : { *(used_in_script) } \
# RUN:         .text : { *(.text) } \
# RUN:       }" > %t.script
# RUN: ld.lld -T %t.script -o %t.so %t.o --gc-sections
# RUN: llvm-objdump -h %t.so | FileCheck %s

# CHECK: Idx Name          Size      Address          Type
# CHECK-NEXT:  0
# CHECK-NEXT:    used_in_reloc
# CHECK-NEXT:    .text
# CHECK-NEXT:    .comment
# CHECK-NEXT:    .symtab
# CHECK-NEXT:    .shstrtab
# CHECK-NEXT:    .strtab

        .global _start
_start:
        .quad __start_used_in_reloc

        .section unused,"a"
        .quad 0

        .section used_in_script,"a"
        .quad __start_used_in_script

        .section used_in_reloc,"a"
        .quad 0
