// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/x86-64-reloc-8.s -o %t1
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/x86-64-reloc-8-error.s -o %t2
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: ld.lld -shared %t %t1 -o /dev/null

// CHECK:      Contents of section .text:
// CHECK-NEXT:   200000 42

// RUN: not ld.lld -shared %t %t2 -o /dev/null 2>&1 | FileCheck --check-prefix=ERROR %s
// ERROR: relocation R_X86_64_8 out of range: 256 is not in [0, 255]

.byte foo
