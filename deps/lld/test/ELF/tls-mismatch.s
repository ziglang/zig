// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/tls-mismatch.s -o %t2
// RUN: not ld.lld %t %t2 -o /dev/null 2>&1 | FileCheck %s

// CHECK: TLS attribute mismatch: tlsvar
// CHECK: >>> defined in
// CHECK: >>> defined in

.globl _start,tlsvar
_start:
  movl tlsvar,%edx
