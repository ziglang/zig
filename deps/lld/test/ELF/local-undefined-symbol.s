# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld %t.o -o %t 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: foo

.global _start
_start:
 jmp foo

.local foo
