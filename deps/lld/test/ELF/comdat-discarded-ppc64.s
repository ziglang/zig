# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc64le %s -o %t.o
# RUN: ld.lld %t.o %t.o -o /dev/null
# RUN: ld.lld -r --fatal-warnings %t.o %t.o -o /dev/null

## clang/gcc PPC64 may emit a .rela.toc which references a switch table in a
## discarded .rodata/.text section. The .toc and the .rela.toc are incorrectly
## not placed in the comdat.
## Don't error "relocation refers to a discarded section".

.section .text.foo,"axG",@progbits,foo,comdat
.globl foo
foo:
.L0:

.section .toc,"aw"
.quad .L0
