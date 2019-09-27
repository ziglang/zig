# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -r -o %t %t.o %t.o
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELA %s

# RELA:      Relocations [
# RELA-NEXT:   Section ({{.*}}) .rela.data {
# RELA-NEXT:     0x0 R_X86_64_32 .text 0x1
# RELA-NEXT:     0x4 R_X86_64_32 .text 0x5
# RELA-NEXT:   }
# RELA-NEXT: ]


# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
# RUN: ld.lld -r -o %t %t.o %t.o
# RUN: llvm-readobj -r -S --section-data %t | FileCheck --check-prefix=REL %s


# REL:      Section {
# REL:        Index:
# REL:        Name: .data
# REL-NEXT:   Type: SHT_PROGBITS
# REL-NEXT:   Flags [
# REL-NEXT:     SHF_ALLOC
# REL-NEXT:     SHF_WRITE
# REL-NEXT:   ]
# REL-NEXT:   Address:
# REL-NEXT:   Offset:
# REL-NEXT:   Size:
# REL-NEXT:   Link:
# REL-NEXT:   Info:
# REL-NEXT:   AddressAlignment:
# REL-NEXT:   EntrySize:
# REL-NEXT:   SectionData (
# REL-NEXT:     0000: 01000000 05000000                    |
# REL-NEXT:   )
# REL-NEXT: }


# REL:      Relocations [
# REL-NEXT:   Section ({{.*}}) .rel.data {
# REL-NEXT:     0x0 R_386_32 .text 0x0
# REL-NEXT:     0x4 R_386_32 .text 0x0
# REL-NEXT:   }
# REL-NEXT: ]


.long 42
.data
.long .text + 1
