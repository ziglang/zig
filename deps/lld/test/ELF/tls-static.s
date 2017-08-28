// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/shared.s -o %tso
// RUN: ld.lld -static %t -o %tout
// RUN: ld.lld %t -o %tout
// RUN: ld.lld -shared %tso -o %tshared
// RUN: not ld.lld -static %t %tshared -o %tout 2>&1 | FileCheck %s
// REQUIRES: x86

.global _start
_start:
  call __tls_get_addr

// CHECK: error: undefined symbol: __tls_get_addr
// CHECK: >>> referenced by {{.*}}:(.text+0x1)
