# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
# RUN: ld.lld %t1 -o /dev/null --icf=all --print-icf-sections 2>&1 | FileCheck -allow-empty %s

## Check that ICF does not merge sections which relocations have equal addends,
## but different target values.

# CHECK-NOT: selected

.globl und

.section .text
.globl foo
foo:
  .byte 0
.globl bar
bar:
  .byte 0

.section .text.foo, "ax"
.quad foo

.section .text.bar, "ax"
.quad bar
