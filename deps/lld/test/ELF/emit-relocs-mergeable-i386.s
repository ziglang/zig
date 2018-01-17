# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t1
# RUN: ld.lld --emit-relocs %t1 -o %t2
# RUN: llvm-readobj -sections -section-data %t2 | FileCheck %s

## Check lf we produce proper relocations when doing merging of SHF_MERGE sections.

## Check addends of relocations are: 0x0, 0x8, 0x8, 0x4
# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .foo
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_EXECINSTR
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Link:
# CHECK-NEXT:   Info:
# CHECK-NEXT:   AddressAlignment:
# CHECK-NEXT:   EntrySize:
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 00000000 08000000 08000000 04000000
# CHECK-NEXT:   )
# CHECK-NEXT: }

## Check that offsets for AAA is 0x0, for BBB is 0x8 and CCC has offset 0x4.
# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .strings
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_MERGE
# CHECK-NEXT:     SHF_STRINGS
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Link:
# CHECK-NEXT:   Info:
# CHECK-NEXT:   AddressAlignment:
# CHECK-NEXT:   EntrySize:
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     |AAA.CCC.BBB.|
# CHECK-NEXT:   )
# CHECK-NEXT: }

.section .strings,"MS",@progbits,1,unique,10
.Linfo_string0:
  .asciz "AAA"
.Linfo_string1:
  .asciz "BBB"

.section .strings,"MS",@progbits,1,unique,20
.Linfo_string2:
  .asciz "BBB"
.Linfo_string3:
  .asciz "CCC"

.section .foo,"ax",@progbits
.long .Linfo_string0
.long .Linfo_string1
.long .Linfo_string2
.long .Linfo_string3
