# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -o %t.exe -gdb-index %t.o
# RUN: llvm-objdump --section-headers %t.exe | FileCheck %s
# CHECK-NOT: .gdb_index

.global _start
_start:
