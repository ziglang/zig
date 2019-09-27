# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { abc : { *(foo) *(bar) *(zed) } }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o -shared
# RUN: llvm-readobj -S --section-data %t | FileCheck %s

# CHECK:       Section {
# CHECK:        Index:
# CHECK:        Name: abc
# CHECK-NEXT:   Type: SHT_PROGBIT
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
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
# CHECK-NEXT:     0000: 01000000 00000000 61626331 32330002  |........abc123..|
# CHECK-NEXT:     0010: 00000000 000000                      |.......|
# CHECK-NEXT:   )
# CHECK-NEXT: }

        .section foo, "a"
        .quad 1

        .section bar,"aMS",@progbits,1
        .asciz  "abc123"

        .section zed, "a"
        .quad 2
