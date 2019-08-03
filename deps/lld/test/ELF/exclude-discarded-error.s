# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s

# CHECK:      error: relocation refers to a symbol in a discarded section: foo
# CHECK-NEXT: >>> defined in {{.*}}.o
# CHECK-NEXT: >>> referenced by {{.*}}.o:(.text+0x1)

.globl _start
_start:
  jmp foo

.section .foo,"ae"
.globl foo
foo:
