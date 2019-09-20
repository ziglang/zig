# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --emit-relocs %t.o -o %t.exe
# RUN: llvm-readelf --relocations %t.exe | FileCheck %s

# CHECK: 0000000000201004  000000010000000b R_X86_64_32S 0000000000200120 .Lfoo + 8

.globl  _start
_start:
  movq .Lfoo+8, %rax
.section .rodata.cst16,"aM",@progbits,16
.Lfoo:
  .quad 0
  .quad 0
