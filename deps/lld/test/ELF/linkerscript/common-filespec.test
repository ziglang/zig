# REQUIRES: x86
# RUN: echo '.long 0; .comm common_uniq_0,4,4; .comm common_multiple,8,8' \
# RUN:   | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %tfile0.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/common-filespec1.s -o %tfile1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/common-filespec2.s -o %tfile2.o
# RUN: ld.lld -o %t1 --script %s %tfile0.o %tfile1.o %tfile2.o
# RUN: llvm-readobj -s -t %t1 | FileCheck %s

SECTIONS {
  .common_0 : { *file0.o(COMMON) }
  .common_1 : { *file1.o(COMMON) }
  .common_2 : { *file2.o(COMMON) }
}

# Make sure all 3 sections are allocated and they have sizes and alignments
# corresponding to the commons assigned to them
# CHECK:       Section {
# CHECK:         Index:
# CHECK:         Name: .common_0
# CHECK-NEXT:    Type: SHT_NOBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x4
# CHECK-NEXT:    Offset: 0x
# CHECK-NEXT:    Size: 4
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 4
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }
# CHECK:       Section {
# CHECK:         Index:
# CHECK:         Name: .common_1
# CHECK-NEXT:    Type: SHT_NOBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x8
# CHECK-NEXT:    Offset: 0x
# CHECK-NEXT:    Size: 8
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 8
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }
# CHECK:       Section {
# CHECK:         Index:
# CHECK:         Name: .common_2
# CHECK-NEXT:    Type: SHT_NOBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x10
# CHECK-NEXT:    Offset: 0x
# CHECK-NEXT:    Size: 48
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 16
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }

# Commons with unique name in each file must be assigned to that file's section.
# For a common with multiple definitions, the largest one wins and it must be
# assigned to the section from the file which provided the winning def
# CHECK:       Symbol {
# CHECK:         Name: common_multiple
# CHECK-NEXT:    Value: 0x10
# CHECK-NEXT:    Size: 32
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common_2
# CHECK-NEXT:  }
# CHECK:       Symbol {
# CHECK:         Name: common_uniq_0
# CHECK-NEXT:    Value: 0x4
# CHECK-NEXT:    Size: 4
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common_0
# CHECK-NEXT:  }
# CHECK:       Symbol {
# CHECK:         Name: common_uniq_1
# CHECK-NEXT:    Value: 0x8
# CHECK-NEXT:    Size: 8
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common_1
# CHECK-NEXT:  }
# CHECK:       Symbol {
# CHECK:         Name: common_uniq_2
# CHECK-NEXT:    Value: 0x30
# CHECK-NEXT:    Size: 16
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common_2
# CHECK-NEXT:  }
