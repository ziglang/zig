# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux /dev/null -o %t.o
# RUN: ld.lld -o %t1 --script %s %t.o

## Check we do not crash.

PHDRS { foo PT_DYNAMIC; }

SECTIONS {
  .text : { *(.text) } : foo
}
