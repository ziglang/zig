// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/relocation-copy-relro.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t.so
// RUN: ld.lld --hash-style=sysv %t.o %t.so -o %t3
// RUN: llvm-readobj -S -l -r %t3 | FileCheck %s

// CHECK:        Name: .bss.rel.ro (48)
// CHECK-NEXT:   Type: SHT_NOBITS (0x8)
// CHECK-NEXT:   Flags [ (0x3)
// CHECK-NEXT:     SHF_ALLOC (0x2)
// CHECK-NEXT:     SHF_WRITE (0x1)
// CHECK-NEXT:   ]
// CHECK-NEXT:   Address: 0x2020B0
// CHECK-NEXT:   Offset: 0x20B0
// CHECK-NEXT:   Size: 8

// CHECK: 0x2020B0 R_X86_64_COPY a 0x0
// CHECK: 0x2020B4 R_X86_64_COPY b 0x0

// CHECK:      Type: PT_GNU_RELRO (0x6474E552)
// CHECK-NEXT: Offset: 0x2000
// CHECK-NEXT: VirtualAddress: 0x202000
// CHECK-NEXT: PhysicalAddress: 0x202000
// CHECK-NEXT: FileSize: 176
// CHECK-NEXT: MemSize: 4096

.text
.global _start
_start:
movl $1, a
movl $2, b
