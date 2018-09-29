// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/ppc64-addr16-error.s -o %t2
// RUN: not ld.lld -shared %t %t2 -o /dev/null 2>&1 | FileCheck %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/ppc64-addr16-error.s -o %t2
// RUN: not ld.lld -shared %t %t2 -o /dev/null 2>&1 | FileCheck %s

.short sym+65539

// CHECK: relocation R_PPC64_ADDR16 out of range: 65539 is not in [-32768, 32767]
