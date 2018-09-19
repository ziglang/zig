// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/tls-mismatch.s -o %t2
// RUN: rm -f %t.a
// RUN: llvm-ar cru %t.a %t2
// RUN: ld.lld %t.a %t -o /dev/null

.globl _start,tlsvar
_start:
  movq tlsvar@GOTTPOFF(%rip),%rdx
