# REQUIRES: x86
# RUN: echo '.section .zed, "a"; .zero 4' \
# RUN:   | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t.o
# RUN: ld.lld --script %s %t.o -o %t
# RUN: llvm-readelf -l -S -W %t | FileCheck %s

# CHECK: [ 1] .abc              PROGBITS        0000000000001000 001000 000004 00   A  0   0  1
# CHECK: LOAD           0x000000 0x0000000000000000 0x0000000000000000 0x001004 0x001004 R E 0x1000

PHDRS { foobar PT_LOAD FILEHDR PHDRS; }

SECTIONS {
  . = 0x1000;
  .abc : { *(.zed) } : foobar
}
