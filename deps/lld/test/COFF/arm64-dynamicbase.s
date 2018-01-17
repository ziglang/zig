// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-windows %s -o %t.obj
// RUN: not lld-link -entry:_start -subsystem:console %t.obj -out:%t.exe -dynamicbase:no 2>&1 | FileCheck %s
 .globl _start
_start:
 ret

# CHECK: dynamicbase:no is not compatible with arm64
