# REQUIRES: x86, zlib

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/compress-debug.s -o %t2.o
# RUN: ld.lld %t2.o %t.o -o %t1 --compress-debug-sections=zlib -Ttext=0
# RUN: llvm-dwarfdump %t1 -debug-str | FileCheck %s
# These two checks correspond to the patched values of a_sym and a_debug_sym.
# D = 0x44 - address of .text input section for this file (the start address of
#     .text is 0 as requested on the command line, and the size of the
#	  preceding .text in the other input file is 0x44).
# C = 0x43 - offset of .debug_info section for this file (the size of
#     the preceding .debug_info from the other input file is 0x43).
# CHECK: 0x00000000: "D"
# CHECK: 0x00000004: "C"

.text
a_sym:
nop

.section .debug_str,"",@progbits
.long a_sym
.long a_debug_sym

.section .debug_info,"",@progbits
a_debug_sym:
.long 0x88776655
