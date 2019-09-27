# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj --symbols -r --dyn-syms %t.so | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj --symbols -r --dyn-syms %t.so | FileCheck %s

.section        ".toc","aw"
.quad weakfunc
// CHECK-NOT: R_PPC64_RELATIVE

.text
.Lfoo:
  bl weakfunc
  nop
// CHECK-NOT: R_PPC64_REL24

.weak weakfunc
