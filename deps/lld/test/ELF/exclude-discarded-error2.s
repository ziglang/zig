# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: echo '.section .foo,"ae"; .weak foo; foo:' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64 - -o %t1.o
# RUN: not ld.lld %t.o %t1.o -o /dev/null 2>&1 | FileCheck %s

# Because foo defined in %t1.o is weak, it does not override global undefined
# in %t.o
# CHECK-NOT: discarded section
# CHECK: undefined symbol: foo

.globl _start
_start:
  jmp foo
