// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %S/Inputs/x86-64-reloc-16.s -o %t1
// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %S/Inputs/x86-64-reloc-16-error.s -o %t2
// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t
// RUN: ld.lld -shared %t %t1 -o %t3
// RUN: llvm-objdump -s %t3 | FileCheck %s

// CHECK:      Contents of section .text:
// CHECK-NEXT:   1000 42

// RUN: not ld.lld -shared %t %t2 -o /dev/null 2>&1 | FileCheck --check-prefix=ERROR %s
// ERROR: relocation R_386_16 out of range: 65536 is not in [-32768, 32767]

.short foo
