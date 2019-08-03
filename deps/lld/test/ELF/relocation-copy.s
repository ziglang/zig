// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/relocation-copy.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t.so
// RUN: ld.lld %t.o %t.so -o %t3
// RUN: llvm-readobj -S -r --expand-relocs %t3 | FileCheck %s
// RUN: llvm-objdump -d %t3 | FileCheck -check-prefix=CODE %s

.text
.global _start
_start:
movl $5, x
movl $7, y
movl $9, z
movl $x, %edx
movl $y, %edx
movl $z, %edx

// CHECK:      Name: .bss
// CHECK-NEXT:  Type: SHT_NOBITS (0x8)
// CHECK-NEXT:  Flags [ (0x3)
// CHECK-NEXT:   SHF_ALLOC (0x2)
// CHECK-NEXT:   SHF_WRITE (0x1)
// CHECK-NEXT:  ]
// CHECK-NEXT:  Address: 0x203000
// CHECK-NEXT:  Offset:
// CHECK-NEXT:  Size: 24
// CHECK-NEXT:  Link: 0
// CHECK-NEXT:  Info: 0
// CHECK-NEXT:  AddressAlignment: 16
// CHECK-NEXT:  EntrySize: 0

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset:
// CHECK-NEXT:       Type: R_X86_64_COPY
// CHECK-NEXT:       Symbol: x
// CHECK-NEXT:       Addend: 0x0
// CHECK-NEXT:     }
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset:
// CHECK-NEXT:       Type: R_X86_64_COPY
// CHECK-NEXT:       Symbol: y
// CHECK-NEXT:       Addend: 0x0
// CHECK-NEXT:     }
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset:
// CHECK-NEXT:       Type: R_X86_64_COPY
// CHECK-NEXT:       Symbol: z
// CHECK-NEXT:       Addend: 0x0
// CHECK-NEXT:     }
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// 2109440 = 0x203000
// 16 is alignment here
// 2109456 = 0x203000 + 16
// 2109460 = 0x203000 + 16 + 4
// CODE: Disassembly of section .text:
// CODE-EMPTY:
// CODE-NEXT: _start:
// CODE-NEXT: 201000: {{.*}} movl $5, 2109440
// CODE-NEXT: 20100b: {{.*}} movl $7, 2109456
// CODE-NEXT: 201016: {{.*}} movl $9, 2109460
// CODE-NEXT: 201021: {{.*}} movl $2109440, %edx
// CODE-NEXT: 201026: {{.*}} movl $2109456, %edx
// CODE-NEXT: 20102b: {{.*}} movl $2109460, %edx
