# REQUIRES: x86
# RUN: llvm-mc -position-independent -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:  . = 0xffffffff80000000; \
# RUN:  .text : ALIGN(4096) { *(.text) } \
# RUN:  .data : ALIGN(4096) { *(.data) } \
# RUN:  .bss : ALIGN(4096) { *(.bss); } \
# RUN:  . = ALIGN(4096); \
# RUN:  _end = .; \
# RUN:  /DISCARD/ : { *(.comment) } \
# RUN: }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readelf -s -symbols %t | FileCheck %s

# CHECK: .bss NOBITS ffffffff80002000 002008 000002 00 WA 0 0 4096
# CHECK: ffffffff80003000 0 NOTYPE GLOBAL DEFAULT 3 _end

.section .text, "ax"
  ret

.section .data, "aw"
  .quad 0

.section .bss, "", @nobits
  .short 0
