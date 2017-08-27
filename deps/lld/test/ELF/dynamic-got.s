// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -s -l -section-data -r %t.so | FileCheck %s

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size:
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment:
// CHECK-NEXT: EntrySize:
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 00200000                |
// CHECK-NEXT: )

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rel.dyn {
// CHECK-NEXT:     0x2050 R_386_RELATIVE - 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// CHECK:      Type: PT_DYNAMIC
// CHECK-NEXT: Offset: 0x2000
// CHECK-NEXT: VirtualAddress: 0x2000
// CHECK-NEXT: PhysicalAddress: 0x2000

        calll   .L0$pb
.L0$pb:
        popl    %eax
.Ltmp0:
        addl    $_GLOBAL_OFFSET_TABLE_+(.Ltmp0-.L0$pb), %eax
        movl    _DYNAMIC@GOT(%eax), %eax
