// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/copy-relocation-zero-abs-addr.s -o %t.o
// RUN: ld.lld -shared -o %t2.so %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t3.o
// RUN: ld.lld %t2.so %t3.o -o %t4
// RUN: llvm-readobj --symbols %t2.so | FileCheck -check-prefix=ABSADDR %s
// RUN: llvm-readobj -S -r --expand-relocs %t4 | FileCheck %s

// This tests that symbols with absolute addresses are properly
// handled. Normal DSO symbols are handled as usual.

.text
.globl _start
_start:
  movl $5, foo

// ABSADDR:        Name: ver1
// ABSADDR-NEXT:   Value: 0x0
// ABSADDR-NEXT:   Size: 0
// ABSADDR-NEXT:   Binding: Global
// ABSADDR-NEXT:   Type: None
// ABSADDR-NEXT:   Other: 0
// ABSADDR-NEXT:   Section: Absolute (0xFFF1)
// ABSADDR-NEXT: }
// ABSADDR-NEXT: Symbol {
// ABSADDR-NEXT:   Name: ver2
// ABSADDR-NEXT:   Value: 0x0
// ABSADDR-NEXT:   Size: 0
// ABSADDR-NEXT:   Binding: Global
// ABSADDR-NEXT:   Type: None
// ABSADDR-NEXT:   Other: 0
// ABSADDR-NEXT:   Section: Absolute (0xFFF1)
// ABSADDR-NEXT: }

// CHECK:      Relocations [
// CHECK-NEXT:   Section (5) .rela.dyn {
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset:
// CHECK-NEXT:       Type: R_X86_64_COPY
// CHECK-NEXT:       Symbol: foo
// CHECK-NEXT:       Addend:
// CHECK-NEXT:     }
// CHECK-NEXT:   }
// CHECK-NEXT: ]
