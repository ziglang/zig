# REQUIRES: x86

## In this test R_X86_64_GOTTPOFF is a IE relocation (static TLS model),
## test check we add STATIC_TLS flag.

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t1 -shared
# RUN: llvm-readobj --dynamic-table %t1 | FileCheck %s

# CHECK: DynamicSection [
# CHECK: FLAGS STATIC_TLS

.section ".tdata", "awT", @progbits
.globl var
var:

movq var@GOTTPOFF(%rip), %rax # R_X86_64_GOTTPOFF
movl %fs:0(%rax), %eax
