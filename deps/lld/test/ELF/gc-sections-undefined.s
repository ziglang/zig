# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t1 --gc-sections --undefined=foo
# RUN: llvm-readobj --symbols %t1 | FileCheck %s

# CHECK: foo

.section .foo,"ax"
.global foo
foo:
