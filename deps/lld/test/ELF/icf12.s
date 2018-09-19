# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
# RUN: ld.lld %t1 -o /dev/null --icf=all --print-icf-sections 2>&1 | FileCheck -allow-empty %s

# Check that ICF does not merge 2 sections which relocations
# differs in addend only.

# CHECK-NOT: selected

.section .text
.globl _start
_start:
  ret

.section .text.foo, "ax"
.quad _start + 1

.section .text.bar, "ax"
.quad _start + 2
