# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
# RUN: ld.lld -shared -z notext %t1 -o /dev/null --icf=all --print-icf-sections 2>&1 | FileCheck -allow-empty %s

## Check that ICF does not merge sections which relocations point to symbols
## that are not of the regular defined kind. 

# CHECK-NOT: selected

.globl und

.section .text
.globl _start
_start:
  ret

.section .text.foo, "ax"
.quad _start

.section .text.bar, "ax"
.quad und
