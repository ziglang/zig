# REQUIRES: x86
# RUN: echo '.section .init_array, "aw"; .quad 0' \
# RUN:   | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t.o
# RUN: ld.lld %t.o -script %s -o %t 2>&1

SECTIONS {
  .init_array : {
    __init_array_start = .;
    *(.init_array)
    __init_array_end = .;
  }
}
