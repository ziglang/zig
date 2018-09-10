# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
# RUN: ld.lld %t1 -o /dev/null --icf=all --print-icf-sections 2>&1 | FileCheck -allow-empty %s

# CHECK-NOT: selected

.section .text
.globl _start
_start:
  ret

.section .aaa, "ax",%progbits,unique,1
.quad _start

.section .aaa, "axS",%progbits,unique,2
.quad _start
