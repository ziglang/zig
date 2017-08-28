# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: not ld.lld %t -o %t2
# RUN: ld.lld %t --noinhibit-exec -o %t2
# RUN: llvm-objdump -d %t2 | FileCheck %s
# REQUIRES: x86

# CHECK: Disassembly of section .text:
# CHECK-NEXT: _start
# CHECK-NEXT: 201000: {{.*}} callq -2101253

# next code will not link without noinhibit-exec flag
# because of undefined symbol _bar
.globl _start
_start:
  call _bar
