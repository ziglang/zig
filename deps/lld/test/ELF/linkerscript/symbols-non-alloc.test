# REQUIRES: x86
# RUN: echo '.section .nonalloc,""; .quad 0' \
# RUN:   | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t
# RUN: ld.lld -o %t2 --script %s %t
# RUN: llvm-objdump -section-headers -t %t2 | FileCheck %s

# CHECK: Sections:
# CHECK:  .nonalloc     00000008 0000000000000000

# CHECK: SYMBOL TABLE:
# CHECK:  0000000000000008 .nonalloc 00000000 Sym

SECTIONS {
  . = SIZEOF_HEADERS;
  .text : { *(.text) }
  .nonalloc : { *(.nonalloc) }
  Sym = .;
}
