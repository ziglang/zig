# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc-unknown-freebsd %s -o %t
# RUN: ld.lld %t -o %t2 -shared
# RUN: llvm-readobj -r %t2 | FileCheck %s

.data
  .long foo

// CHECK:      Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:   0x20000 R_PPC_ADDR32 foo 0x0
// CHECK-NEXT: }
