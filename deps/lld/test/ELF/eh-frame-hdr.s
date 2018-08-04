// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

// RUN: ld.lld %t.o -o %t
// RUN: llvm-readobj -file-headers -s -section-data -program-headers -symbols %t \
// RUN:   | FileCheck %s --check-prefix=NOHDR

// RUN: ld.lld -eh-frame-hdr -no-eh-frame-hdr %t.o -o %t
// RUN: llvm-readobj -file-headers -s -section-data -program-headers -symbols %t \
// RUN:   | FileCheck %s --check-prefix=NOHDR

// RUN: ld.lld --eh-frame-hdr %t.o -o %t
// RUN: llvm-readobj -file-headers -s -section-data -program-headers -symbols %t \
// RUN:   | FileCheck %s --check-prefix=HDR
// RUN: llvm-objdump -d %t | FileCheck %s --check-prefix=HDRDISASM

.section foo,"ax",@progbits
.cfi_startproc
 nop
.cfi_endproc

.section bar,"ax",@progbits
.cfi_startproc
 nop
.cfi_endproc

.section dah,"ax",@progbits
.cfi_startproc
 nop
.cfi_endproc

.text
.globl _start
_start:

// NOHDR:       Sections [
// NOHDR-NOT:    Name: .eh_frame_hdr
// NOHDR:      ProgramHeaders [
// NOHDR-NOT:   PT_GNU_EH_FRAME

//HDRDISASM:      Disassembly of section foo:
//HDRDISASM-NEXT: foo:
//HDRDISASM-NEXT:    201000: 90 nop
//HDRDISASM-NEXT: Disassembly of section bar:
//HDRDISASM-NEXT: bar:
//HDRDISASM-NEXT:    201001: 90 nop
//HDRDISASM-NEXT: Disassembly of section dah:
//HDRDISASM-NEXT: dah:
//HDRDISASM-NEXT:    201002: 90 nop

// HDR:       Section {
// HDR:         Index:
// HDR:         Name: .eh_frame_hdr
// HDR-NEXT:    Type: SHT_PROGBITS
// HDR-NEXT:    Flags [
// HDR-NEXT:      SHF_ALLOC
// HDR-NEXT:    ]
// HDR-NEXT:    Address: 0x200158
// HDR-NEXT:    Offset: 0x158
// HDR-NEXT:    Size: 36
// HDR-NEXT:    Link: 0
// HDR-NEXT:    Info: 0
// HDR-NEXT:    AddressAlignment: 4
// HDR-NEXT:    EntrySize: 0
// HDR-NEXT:    SectionData (
// HDR-NEXT:      0000: 011B033B 24000000 03000000 A80E0000
// HDR-NEXT:      0010: 40000000 A90E0000 58000000 AA0E0000
// HDR-NEXT:      0020: 70000000
// HDR-NEXT:    )
//              Header (always 4 bytes): 0x011B033B
//                 24000000 = .eh_frame(0x200180) - .eh_frame_hdr(0x200158) - 4
//                 03000000 = 3 = the number of FDE pointers in the table.
//              Entry(1): A80E0000 40000000
//                 480E0000 = 0x201000 - .eh_frame_hdr(0x200158) = 0xEA8
//                 40000000 = address of FDE(1) - .eh_frame_hdr(0x200158) =
//                    = .eh_frame(0x200180) + 24 - 0x200158 = 0x40
//              Entry(2): A90E0000 58000000
//                 A90E0000 = 0x201001 - .eh_frame_hdr(0x200158) = 0xEA9
//                 58000000 = address of FDE(2) - .eh_frame_hdr(0x200158) =
//                    = .eh_frame(0x200180) + 24 + 24 - 0x200158 = 0x58
//              Entry(3): AA0E0000 70000000
//                 AA0E0000 = 0x201002 - .eh_frame_hdr(0x200158) = 0xEAA
//                 70000000 = address of FDE(3) - .eh_frame_hdr(0x200158) =
//                    = .eh_frame(0x200180) + 24 + 24 + 24 - 0x200158 = 0x70
// HDR-NEXT:  }
// HDR-NEXT:  Section {
// HDR-NEXT:    Index:
// HDR-NEXT:    Name: .eh_frame
// HDR-NEXT:    Type: SHT_PROGBITS
// HDR-NEXT:    Flags [
// HDR-NEXT:      SHF_ALLOC
// HDR-NEXT:    ]
// HDR-NEXT:    Address: 0x200180
// HDR-NEXT:    Offset: 0x180
// HDR-NEXT:    Size: 100
// HDR-NEXT:    Link: 0
// HDR-NEXT:    Info: 0
// HDR-NEXT:    AddressAlignment: 8
// HDR-NEXT:    EntrySize: 0
// HDR-NEXT:    SectionData (
// HDR-NEXT:      0000: 14000000 00000000 017A5200 01781001
// HDR-NEXT:      0010: 1B0C0708 90010000 14000000 1C000000
// HDR-NEXT:      0020: 600E0000 01000000 00000000 00000000
// HDR-NEXT:      0030: 14000000 34000000 490E0000 01000000
// HDR-NEXT:      0040: 00000000 00000000 14000000 4C000000
// HDR-NEXT:      0050: 320E0000 01000000 00000000 00000000
// HDR-NEXT:      0060: 00000000
// HDR-NEXT:    )
//            CIE: 14000000 00000000 017A5200 01781001 1B0C0708 90010000
//            FDE(1): 14000000 1C000000 600E0000 01000000 00000000 00000000
//                    address of data (starts with 0x600E0000) = 0x200180 + 0x0020 = 0x2001A0
//                    The starting address to which this FDE applies = 0xE60 + 0x2001A0 = 0x201000
//                    The number of bytes after the start address to which this FDE applies = 0x01000000 = 1
//            FDE(2): 14000000 34000000 490E0000 01000000 00000000 00000000
//                    address of data (starts with 0x490E0000) = 0x200180 + 0x0038 = 0x2001B8
//                    The starting address to which this FDE applies = 0xE49 + 0x2001B8 = 0x201001
//                    The number of bytes after the start address to which this FDE applies = 0x01000000 = 1
//            FDE(3): 14000000 4C000000 320E0000 01000000 00000000 00000000
//                    address of data (starts with 0x320E0000) = 0x200180 + 0x0050 = 0x2001D0
//                    The starting address to which this FDE applies = 0xE5A + 0x2001D0 = 0x201002
//                    The number of bytes after the start address to which this FDE applies = 0x01000000 = 1
// HDR-NEXT:  }
// HDR:     ProgramHeaders [
// HDR:      ProgramHeader {
// HDR:       Type: PT_GNU_EH_FRAME
// HDR-NEXT:   Offset: 0x158
// HDR-NEXT:   VirtualAddress: 0x200158
// HDR-NEXT:   PhysicalAddress: 0x200158
// HDR-NEXT:   FileSize: 36
// HDR-NEXT:   MemSize: 36
// HDR-NEXT:   Flags [
// HDR-NEXT:     PF_R
// HDR-NEXT:   ]
// HDR-NEXT:   Alignment: 4
// HDR-NEXT: }
