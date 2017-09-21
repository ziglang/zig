# REQUIRES: x86

# Linker-synthesized sections shouldn't be gc'ed.

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t1
# RUN: ld.lld %t1 -shared -o %t.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2
# RUN: ld.lld %t2 %t.so -build-id -dynamic-linker /foo/bar -o %t.out
# RUN: llvm-readobj -sections %t.out | FileCheck %s

# CHECK: Name: .interp
# CHECK: Name: .note.gnu.build-id

.globl _start
_start:
  ret
