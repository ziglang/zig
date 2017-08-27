// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/relocation-copy-align.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t.so
// RUN: ld.lld %t.o %t.so -o %t3
// RUN: llvm-readobj -s -r --expand-relocs %t3 | FileCheck %s

.global _start
_start:
movl $5, x

// CHECK:    Name: .bss
// CHECK-NEXT:    Type: SHT_NOBITS
// CHECK-NEXT:    Flags [
// CHECK-NEXT:      SHF_ALLOC
// CHECK-NEXT:      SHF_WRITE
// CHECK-NEXT:    ]
// CHECK-NEXT:    Address:
// CHECK-NEXT:    Offset:
// CHECK-NEXT:    Size: 4
// CHECK-NEXT:    Link:
// CHECK-NEXT:    Info:
// CHECK-NEXT:    AddressAlignment: 4
// CHECK-NEXT:    EntrySize:

// CHECK:      Relocation {
// CHECK-NEXT:   Offset:
// CHECK-NEXT:   Type: R_X86_64_COPY
// CHECK-NEXT:   Symbol: x
// CHECK-NEXT:   Addend: 0x0
// CHECK-NEXT: }
