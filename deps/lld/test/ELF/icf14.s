# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
# RUN: ld.lld %t1 -o /dev/null --icf=all --print-icf-sections 2>&1 | FileCheck -allow-empty %s

# Check that ICF does not merge 2 sections which relocations
# refer to symbols that live in sections of the different types
# (regular input section and mergeable input sections in this case).

# CHECK-NOT: selected

.section .text
.globl _start
_start:
  ret

.section .rodata.str,"aMS",@progbits,1
.globl rodata
rodata:
.asciz "foo"

.section .text.foo, "ax"
.quad rodata

.section .text.bar, "ax"
.quad _start
