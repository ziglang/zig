# REQUIRES: mips
# Check that the linker use a value of _gp symbol defined
# in a linker script to calculate GOT relocations.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o

# RUN: echo "SECTIONS { \
# RUN:          .text : { *(.text) } \
# RUN:          _gp = ABSOLUTE(.) + 0x100; \
# RUN:          .got  : { *(.got) } }" > %t.rel.script
# RUN: ld.lld -shared -o %t.rel.so --script %t.rel.script %t.o
# RUN: llvm-objdump -s -t %t.rel.so | FileCheck --check-prefix=REL %s

# RUN: echo "SECTIONS { \
# RUN:          .text : { *(.text) } \
# RUN:          _gp = 0x100 + ABSOLUTE(.); \
# RUN:          .got  : { *(.got) } }" > %t.rel.script
# RUN: ld.lld -shared -o %t.rel.so --script %t.rel.script %t.o
# RUN: llvm-objdump -s -t %t.rel.so | FileCheck --check-prefix=REL %s

# RUN: echo "SECTIONS { \
# RUN:          .text : { *(.text) } \
# RUN:          _gp = 0x200; \
# RUN:          .got  : { *(.got) } }" > %t.abs.script
# RUN: ld.lld -shared -o %t.abs.so --script %t.abs.script %t.o
# RUN: llvm-objdump -s -t %t.abs.so | FileCheck --check-prefix=ABS %s

# REL:      Contents of section .reginfo:
# REL-NEXT:  0018 10000104 00000000 00000000 00000000
# REL-NEXT:  0028 00000000 000001ec
#                          ^-- _gp

# REL:      Contents of section .text:
# REL-NEXT:  00e0 3c080000 2108010c 8f82ff1c
#                 ^-- %hi(_gp_disp)
#                          ^-- %lo(_gp_disp)
#                                   ^-- 8 - (0x1ec - 0x100)
#                                       G - (GP - .got)

# REL:      Contents of section .data:
# REL-NEXT:  00f0 fffffef4
#                 ^-- 0x30-0x1ec
#                     foo - GP

# REL: 000000e0         .text           00000000 foo
# REL: 00000000         *ABS*           00000000 .hidden _gp_disp
# REL: 000001ec         *ABS*           00000000 .hidden _gp

# ABS:      Contents of section .reginfo:
# ABS-NEXT:  0018 10000104 00000000 00000000 00000000
# ABS-NEXT:  0028 00000000 00000200
#                          ^-- _gp

# ABS:      Contents of section .text:
# ABS-NEXT:  00e0 3c080000 21080120 8f82ff08
#                 ^-- %hi(_gp_disp)
#                          ^-- %lo(_gp_disp)
#                                   ^-- 8 - (0x200 - 0x100)
#                                       G - (GP - .got)

# ABS:      Contents of section .data:
# ABS-NEXT:  00f0 fffffee0
#                 ^-- 0xe0-0x200
#                     foo - GP

# ABS: 000000e0         .text           00000000 foo
# ABS: 00000000         *ABS*           00000000 .hidden _gp_disp
# ABS: 00000200         *ABS*           00000000 .hidden _gp

  .text
foo:
  lui    $t0, %hi(_gp_disp)
  addi   $t0, $t0, %lo(_gp_disp)
  lw     $v0, %call16(bar)($gp)

  .data
  .gpword foo
