# REQUIRES: mips
# Check EI_ABIVERSION flags

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld -shared -o %t.so %t.o
# RUN: llvm-readobj -h %t.so | FileCheck -check-prefix=DSO %s
# RUN: ld.lld -o %t.exe %t.o
# RUN: llvm-readobj -h %t.exe | FileCheck -check-prefix=EXE %s
# RUN: ld.lld -pie -o %t.pie %t.o
# RUN: llvm-readobj -h %t.pie | FileCheck -check-prefix=PIE %s
# RUN: ld.lld -r -o %t.rel %t.o
# RUN: llvm-readobj -h %t.rel | FileCheck -check-prefix=REL %s

# DSO: ABIVersion: 0
# EXE: ABIVersion: 1
# PIE: ABIVersion: 0
# REL: ABIVersion: 0

  .global __start
  .text
__start:
  nop
