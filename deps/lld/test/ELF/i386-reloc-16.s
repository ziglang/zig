// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %S/Inputs/x86-64-reloc-16.s -o %t1
// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %S/Inputs/x86-64-reloc-16-error.s -o %t2
// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t
// RUN: ld.lld -shared %t %t1 -o %t3

// CHECK:      Contents of section .text:
// CHECK-NEXT:   200000 42

// RUN: not ld.lld -shared %t %t2 -o %t4 2>&1 | FileCheck --check-prefix=ERROR %s
// ERROR: relocation R_386_16 out of range: 65536 is not in [0, 65535]

.short foo
