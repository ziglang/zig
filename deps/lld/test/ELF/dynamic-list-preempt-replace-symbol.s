# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: echo '{ common; };' > %t.list
# RUN: ld.lld --dynamic-list %t.list -shared %t.o -o %t.so

# RUN: llvm-readobj -r %t.so | FileCheck %s

# CHECK: R_X86_64_GLOB_DAT common 0x0

movq common@gotpcrel(%rip), %rax

.type common,@object
.comm common,4,4
