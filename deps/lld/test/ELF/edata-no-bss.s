# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t --gc-sections
# RUN: llvm-objdump -t -section-headers %t | FileCheck %s

# CHECK: .data         00000008 0000000000202000 DATA

# CHECK: 0000000000202008         .data                 00000000 _edata

.text
.globl _start
_start:
.long .data - .

.data
.quad 0

.globl _edata
