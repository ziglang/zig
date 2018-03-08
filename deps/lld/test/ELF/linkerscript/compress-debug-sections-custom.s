# REQUIRES: x86, zlib

# RUN: echo "SECTIONS { \
# RUN:          .text : { . += 0x10; *(.text) } \
# RUN:          .debug_str : { . += 0x10; *(.debug_str) } \
# RUN:          .debug_info : { . += 0x10; *(.debug_info) } \
# RUN:          }" > %t.script

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/../Inputs/compress-debug.s -o %t2.o
# RUN: ld.lld %t2.o %t.o -o %t1 --compress-debug-sections=zlib -T %t.script
# RUN: llvm-dwarfdump %t1 -debug-str | FileCheck %s
# These two checks correspond to the patched values of a_sym and a_debug_sym.
# T = 0x54 - address of .text input section for this file (the start address of
#     .text is 0 by default, the size of the preceding .text in the other input
#	  file is 0x44, and the linker script adds an additional 0x10).
# S = 0x53 - offset of .debug_info section for this file (the size of
#     the preceding .debug_info from the other input file is 0x43, and the
#	  linker script adds an additional 0x10).
# Also note that the .debug_str offsets are also offset by 0x10, as directed by
# the linker script.
# CHECK: 0x00000010: "T"
# CHECK: 0x00000014: "S"

.text
a_sym:
nop

.section .debug_str,"",@progbits
.long a_sym
.long a_debug_sym

.section .debug_info,"",@progbits
a_debug_sym:
.long 0x88776655
