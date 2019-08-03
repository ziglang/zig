// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t
// RUN: llvm-readobj -S %t | FileCheck %s

        .section  .rodata.1,"aM",@progbits,1
        .p2align 2
        .byte 0x42

// sh_addralign = 4 while sh_entsize = 3.
// sh_entsize is not necessarily a power of 2 and it can be unrelated to sh_addralign.
        .section  .rodata.2,"aM",@progbits,3
        .p2align 2
        .short 0x42
        .byte 0

// Since the output section has both .rodata.1 and .rodata.2, it
// contains elements of different sizes and we use an entsize of 0.

// CHECK:      Name: .rodata (
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size:
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment: 4
// CHECK-NEXT: EntrySize: 0
