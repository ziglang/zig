// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/relocation-copy-alias.s -o %t2.o
// RUN: ld.lld --hash-style=sysv -shared %t2.o -o %t.so
// RUN: ld.lld --hash-style=sysv %t.o %t.so -o %t3
// RUN: llvm-readobj --dyn-symbols -r --expand-relocs %t3 | FileCheck %s
// RUN: ld.lld --hash-style=sysv --gc-sections %t.o %t.so -o %t3
// RUN: llvm-readobj --dyn-symbols -r --expand-relocs %t3 | FileCheck %s

.global _start
_start:
movl $5, a1
movl $5, b1
movl $5, b2

// CHECK:      .rela.dyn {
// CHECK-NEXT:   Relocation {
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Type: R_X86_64_COPY
// CHECK-NEXT:     Symbol: a1
// CHECK-NEXT:     Addend: 0x0
// CHECK-NEXT:   }
// CHECK-NEXT:   Relocation {
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Type: R_X86_64_COPY
// CHECK-NEXT:     Symbol: b1
// CHECK-NEXT:     Addend: 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: }

// CHECK:      Name: a1
// CHECK-NEXT: Value: [[A:.*]]
// CHECK-NEXT: Size: 1
// CHECK-NEXT: Binding: Global (0x1)
// CHECK-NEXT: Type: Object (0x1)
// CHECK-NEXT: Other: 0
// CHECK-NEXT: Section: .bss (0x7)

// CHECK:      Name: b1
// CHECK-NEXT: Value: [[B:.*]]
// CHECK-NEXT: Size: 1
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type: Object (0x1)
// CHECK-NEXT: Other: 0
// CHECK-NEXT: Section: .bss

// CHECK:      Name: b2
// CHECK-NEXT: Value: [[B]]
// CHECK-NEXT: Size: 1
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type: Object (0x1)
// CHECK-NEXT: Other: 0
// CHECK-NEXT: Section: .bss

// CHECK:      Name: a2
// CHECK-NEXT: Value: [[A]]
// CHECK-NEXT: Size: 1
// CHECK-NEXT: Binding: Weak
// CHECK-NEXT: Type: Object (0x1)
// CHECK-NEXT: Other: 0
// CHECK-NEXT: Section: .bss

// CHECK:      Name: b3
// CHECK-NEXT: Value: [[B]]
// CHECK-NEXT: Size: 1
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type: Object (0x1)
// CHECK-NEXT: Other: 0
// CHECK-NEXT: Section: .bss
