# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: ld.lld -gc-sections -export-dynamic %t -o %t1
# RUN: llvm-readobj --dyn-symbols %t1 | FileCheck %s

# CHECK: Name: bar@
# CHECK: Name: foo@

.comm foo,4,4
.comm bar,4,4

.text
.globl _start
_start:
 .quad foo
