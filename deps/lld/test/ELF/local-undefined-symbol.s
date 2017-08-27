# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t1
# RUN: llvm-readobj -t %t1 | FileCheck %s

# CHECK:     Symbols [
# CHECK-NOT:  Name: foo

.global _start
_start:
 jmp foo

.local foo
