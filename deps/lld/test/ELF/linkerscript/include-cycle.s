# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

# RUN: echo "INCLUDE \"%t1.script\"" > %t1.script
# RUN: not ld.lld %t.o %t1.script 2>&1 | FileCheck %s

# RUN: echo "INCLUDE \"%t2.script\"" > %t1.script
# RUN: echo "INCLUDE \"%t1.script\"" > %t2.script
# RUN: not ld.lld %t.o %t1.script 2>&1 | FileCheck %s

# CHECK: there is a cycle in linker script INCLUDEs

.globl _start
_start:
  ret
