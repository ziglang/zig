// REQUIRES: x86

.cfi_startproc
.cfi_personality 0x1b, bar
.cfi_endproc

.global bar
.hidden bar
bar:

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

// Check the size of the CIE (0x18 + 4) and FDE (0x10 + 4)
// RUN: llvm-readobj -s -section-data %t.o | FileCheck --check-prefix=OBJ %s

// OBJ:      Name: .eh_frame
// OBJ-NEXT: Type:
// OBJ-NEXT: Flags [
// OBJ-NEXT:   SHF_ALLOC
// OBJ-NEXT: ]
// OBJ-NEXT: Address:
// OBJ-NEXT: Offset:
// OBJ-NEXT: Size:
// OBJ-NEXT: Link:
// OBJ-NEXT: Info:
// OBJ-NEXT: AddressAlignment:
// OBJ-NEXT: EntrySize:
// OBJ-NEXT: SectionData (
// OBJ-NEXT:   0000: 18000000 00000000 017A5052 00017810
// OBJ-NEXT:   0010: 061B0000 00001B0C 07089001 10000000
// OBJ-NEXT:   0020: 20000000 00000000 00000000 00000000
// OBJ-NEXT: )

// RUN: ld.lld --hash-style=sysv %t.o -no-rosegment -o %t -shared

// Check that .eh_frame is in the same segment as .text
// RUN: llvm-readobj -l --elf-output-style=GNU %t | FileCheck --check-prefix=PHDR %s

// PHDR: Segment Sections
// PHDR: .text
// PHDR-SAME: .eh_frame

// Check that the CIE and FDE are padded with 0x00 and not 0xCC when the
// .eh_frame section is placed in the executable segment
// RUN: llvm-readobj -s -section-data %t | FileCheck %s

// CHECK:      Name: .eh_frame
// CHECK-NEXT: Type:
// CHECK-NEXT: Flags
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size:
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment:
// CHECK-NEXT: EntrySize:
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 1C000000 00000000 017A5052 00017810
// CHECK-NEXT:   0010: 061BBEFF FFFF1B0C 07089001 00000000
// CHECK-NEXT:   0020: 14000000 24000000 A8FFFFFF 00000000
// CHECK-NEXT:   0030: 00000000 00000000
// CHECK-NEXT: )
