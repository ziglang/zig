# REQUIRES: x86
# RUN: echo '.section .bss,"",@nobits; .short 0' \
# RUN:   | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t.o
# RUN: ld.lld -o %t --script %s %t.o

## Check we do not crash.

SECTIONS {
 .bss : {
   . += 0x10000;
   *(.bss)
 } =0xFF
}
