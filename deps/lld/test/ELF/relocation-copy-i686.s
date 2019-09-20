// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %p/Inputs/relocation-copy.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t.so
// RUN: ld.lld -e main %t.o %t.so -o %t3
// RUN: llvm-readobj -S -r --expand-relocs %t3 | FileCheck %s
// RUN: llvm-objdump -d %t3 | FileCheck -check-prefix=CODE %s

.text
.globl main
.align 16, 0x90
.type main,@function
main:
movl $5, x
movl $7, y
movl $9, z

// CHECK:      Name: .bss
// CHECK-NEXT:  Type: SHT_NOBITS
// CHECK-NEXT:  Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT:  ]
// CHECK-NEXT:  Address:  0x403000
// CHECK-NEXT:  Offset:
// CHECK-NEXT:  Size: 24
// CHECK-NEXT:  Link: 0
// CHECK-NEXT:  Info: 0
// CHECK-NEXT:  AddressAlignment: 16
// CHECK-NEXT:  EntrySize: 0

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rel.dyn {
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset:
// CHECK-NEXT:       Type: R_386_COPY
// CHECK-NEXT:       Symbol: x
// CHECK-NEXT:       Addend: 0x0
// CHECK-NEXT:     }
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset:
// CHECK-NEXT:       Type: R_386_COPY
// CHECK-NEXT:       Symbol: y
// CHECK-NEXT:       Addend: 0x0
// CHECK-NEXT:     }
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset:
// CHECK-NEXT:       Type: R_386_COPY
// CHECK-NEXT:       Symbol: z
// CHECK-NEXT:       Addend: 0x0
// CHECK-NEXT:     }
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// 4206592 =  0x403000
// 16 is alignment here
// 4206608 =  0x403000 + 16
// 4206612 =  0x403000 + 16 + 4
// CODE: Disassembly of section .text:
// CODE-EMPTY:
// CODE-NEXT: main:
// CODE-NEXT: 401000: c7 05 00 30 40 00 05 00 00 00 movl $5, 4206592
// CODE-NEXT: 40100a: c7 05 10 30 40 00 07 00 00 00 movl $7, 4206608
// CODE-NEXT: 401014: c7 05 14 30 40 00 09 00 00 00 movl $9, 4206612
