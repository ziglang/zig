# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
# RUN: ld.lld -shared -z notext %t1 -o /dev/null --icf=all --print-icf-sections 2>&1 | FileCheck -allow-empty %s

## ICF is able to merge sections which relocations referring regular input sections
## or mergeable sections. .eh_frame is represented with a different kind of section,
## here we check that ICF code is able to handle and will not merge sections which
## relocations referring .eh_frame.

# CHECK-NOT: selected

.section ".eh_frame", "a", @progbits
.globl foo
foo:
  .quad 0
.globl bar
bar:
  .quad 0

.section .text.foo, "ax"
.quad foo

.section .text.bar, "ax"
.quad bar
