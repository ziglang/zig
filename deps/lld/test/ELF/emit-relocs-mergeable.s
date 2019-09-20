# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1
# RUN: ld.lld --emit-relocs %t1 -o %t2
# RUN: llvm-readobj --sections --section-data -r %t2 | FileCheck %s

## Check if we produce proper relocations when doing merging of SHF_MERGE sections.

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
# CHECK-NEXT:   Size: 12
# CHECK-NEXT:   Link:
# CHECK-NEXT:   Info:
# CHECK-NEXT:   AddressAlignment:
# CHECK-NEXT:   EntrySize:
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 41414100 43434300 42424200 |AAA.CCC.BBB.|
# CHECK-NEXT:   )
# CHECK-NEXT: }

# CHECK:      Relocations [
# CHECK-NEXT:   Section {{.*}} .rela.foo {
# CHECK-NEXT:     0x201000 R_X86_64_64 .strings 0x0
# CHECK-NEXT:     0x201008 R_X86_64_64 .strings 0x8
# CHECK-NEXT:     0x201010 R_X86_64_64 .strings 0x8
# CHECK-NEXT:     0x201018 R_X86_64_64 .strings 0x4
# CHECK-NEXT:   }
# CHECK-NEXT: ]

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
.quad .Linfo_string0
.quad .Linfo_string1
.quad .Linfo_string2
.quad .Linfo_string3
