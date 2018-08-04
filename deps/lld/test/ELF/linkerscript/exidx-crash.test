# REQUIRES: aarch64

# We used to crash on this.

# RUN: llvm-mc /dev/null -o %t.o -filetype=obj -triple=aarch64-pc-linux
# RUN: ld.lld -T %s %t.o -o %t

SECTIONS {
  .ARM.exidx : { *(.foo) }
}
