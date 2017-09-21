# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-freebsd %s -o %t
# RUN: ld.lld -shared %t -o %t.so
# RUN: ld.lld %t %t.so -o %t.exe
# RUN: llvm-readobj -dynamic-table %t.so | FileCheck -check-prefix=DSO %s
# RUN: llvm-readobj -dynamic-table %t.exe | FileCheck -check-prefix=EXE %s

# EXE: DynamicSection [
# EXE:   0x0000000000000015 DEBUG                0x0
# EXE: ]

# DSO: DynamicSection [
# DSO-NOT:   0x0000000000000015 DEBUG                0x0
# DSO: ]

.globl _start
_start:
