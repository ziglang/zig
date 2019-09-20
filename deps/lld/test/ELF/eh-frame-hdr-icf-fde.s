# REQUIRES: x86

## Testcase checks that we correctly deduplicate FDEs when ICF
## merges two sections.

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2 --icf=all --eh-frame-hdr
# RUN: llvm-readobj -r %t | FileCheck %s --check-prefix=OBJ
# RUN: llvm-readobj -S --section-data %t2 | FileCheck %s

# OBJ:      Relocations [
# OBJ-NEXT:   Section {{.*}} .rela.eh_frame {
# OBJ-NEXT:     0x20 R_X86_64_PC32 .text.f1 0x0
# OBJ-NEXT:     0x34 R_X86_64_PC32 .text.f1 0x2
# OBJ-NEXT:     0x48 R_X86_64_PC32 .text.f2 0x0
# OBJ-NEXT:     0x5C R_X86_64_PC32 .text.f2 0x2
# OBJ-NEXT:   }
# OBJ-NEXT: ]

# CHECK:      Section {
# CHECK:        Index: 1
# CHECK:        Name: .eh_frame_hdr
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x200158
# CHECK-NEXT:   Offset: 0x158
# CHECK-NEXT:   Size: 28
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment:
# CHECK-NEXT:   EntrySize: 0
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 011B033B 1C000000 02000000 A80E0000
##                               ^        ^-- FDE(1) PC
##                               ^-- Number of FDEs
# CHECK-NEXT:     0010: 38000000 AA0E0000 50000000
##                               ^-- FDE(2) PC
# CHECK-NEXT:   )
# CHECK-NEXT: }
## FDE(1) == 0x201000 - .eh_frame_hdr(0x200158) = 0xEA8
## FDE(2) == 0x201000 - .eh_frame_hdr(0x200158) + 2(relocation addend) = 0xEAA

## Check .eh_frame contains CIE and two FDEs remaining after ICF.
# CHECK-NEXT: Section {
# CHECK-NEXT:   Index: 2
# CHECK-NEXT:   Name: .eh_frame
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x200178
# CHECK-NEXT:   Offset: 0x178
# CHECK-NEXT:   Size: 76
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 8
# CHECK-NEXT:   EntrySize: 0
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 14000000 00000000 017A5200 01781001
# CHECK-NEXT:     0010: 1B0C0708 90010000 14000000 1C000000
# CHECK-NEXT:     0020: 680E0000 01000000 00000000 00000000
# CHECK-NEXT:     0030: 14000000 34000000 520E0000 01000000
# CHECK-NEXT:     0040: 00000000 00000000 00000000
# CHECK-NEXT:   )
# CHECK-NEXT: }

# CHECK:     Section {
# CHECK:       Index:
# CHECK:       Name: .text
# CHECK-NEXT:  Type: SHT_PROGBITS
# CHECK-NEXT:  Flags [
# CHECK-NEXT:    SHF_ALLOC
# CHECK-NEXT:    SHF_EXECINSTR
# CHECK-NEXT:  ]
# CHECK-NEXT:  Address: 0x201000

.section .text.f1, "ax"
.cfi_startproc
nop
.cfi_endproc
nop
.cfi_startproc
ret
.cfi_endproc

.section .text.f2, "ax"
.cfi_startproc
nop
.cfi_endproc
nop
.cfi_startproc
ret
.cfi_endproc
