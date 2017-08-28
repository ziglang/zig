// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-addr16-error.s -o %t2
// RUN: not ld.lld -shared %t %t2 -o %t3 2>&1 | FileCheck %s
// REQUIRES: ppc

.short sym+65539

// CHECK: relocation R_PPC64_ADDR16 out of range
