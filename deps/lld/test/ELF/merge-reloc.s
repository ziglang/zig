# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -r -o %t-rel
# RUN: llvm-readobj -s -section-data %t-rel | FileCheck %s

# When linker generates a relocatable object it does string merging in the same
# way as for regular link. It should keep SHF_MERGE flag and set proper sh_entsize
# value so that final link can perform the final merging optimization.

# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .rodata.1 (
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_MERGE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size: 4
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 4
# CHECK-NEXT:   EntrySize: 4
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 42000000
# CHECK-NEXT:   )
# CHECK-NEXT: }
# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .rodata.2 (
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_MERGE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size: 8
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 8
# CHECK-NEXT:   EntrySize: 8
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 42000000 42000000
# CHECK-NEXT:   )
# CHECK-NEXT: }
# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .data
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size: 16
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 1
# CHECK-NEXT:   EntrySize: 0
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 42000000 42000000 42000000 42000000
# CHECK-NEXT:   )
# CHECK-NEXT: }

        .section        .rodata.1,"aM",@progbits,4
        .align  4
        .global foo
foo:
        .long   0x42
        .long   0x42
        .long   0x42

        .section        .rodata.2,"aM",@progbits,8
        .align  8
        .global bar
bar:
        .long   0x42
        .long   0x42
        .long   0x42
        .long   0x42

        .data
        .global gar
zed:
        .long   0x42
        .long   0x42
        .long   0x42
        .long   0x42
