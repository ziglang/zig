# REQUIRES: x86
# Verify that .rodata is aligned to a 8 byte boundary.

# RUN: llvm-mc -filetype=obj -triple=i386 %s -o %t.o
# RUN: ld.lld %t.o -o %t.exe -n -Ttext 0
# RUN: llvm-readelf --section-headers %t.exe | FileCheck %s

# CHECK: [ 0]           NULL     00000000 000000 000000 00      0   0  0
# CHECK: [ 1] .text     PROGBITS 00000000 0000d4 000001 00  AX  0   0  4
# CHECK: [ 2] .rodata   PROGBITS 00000008 0000d8 000008 00   A  0   0  8
# CHECK: [ 3] .comment  PROGBITS 00000000 0000e0 000008 01  MS  0   0  1
# CHECK: [ 4] .symtab   SYMTAB   00000000 0000e8 000020 10      6   1  4
# CHECK: [ 5] .shstrtab STRTAB   00000000 000108 000032 00      0   0  1
# CHECK: [ 6] .strtab   STRTAB   00000000 00013a 000008 00      0   0  1

.globl _start
.text
_start:
  ret

.rodata
.align 8
.quad 42
