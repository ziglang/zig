# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/gnu-ifunc-dso.s -o %t1.o
# RUN: ld.lld -shared %t1.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
# RUN: ld.lld -shared %t2.o %t.so -o %t
# RUN: llvm-readobj -dyn-relocations %t | FileCheck %s

# CHECK:      Dynamic Relocations {
# CHECK-NEXT:   0x1000 R_X86_64_64 foo 0x0
# CHECK-NEXT: }

.data
 .quad foo
