// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: not ld.lld %t.o -o %t 2>&1 | FileCheck %s

// CHECK:      error: section type mismatch for .shstrtab
// CHECK-NEXT: >>> <internal>:(.shstrtab): SHT_STRTAB
// CHECK-NEXT: >>> output section .shstrtab: Unknown

.section .shstrtab,"",@12345
.short 20
