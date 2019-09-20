# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %tfile0.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/common-filespec1.s -o %tfile1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/common-filespec2.s -o %tfile2.o
# RUN: echo "SECTIONS { .common.incl : { *(EXCLUDE_FILE (*file2.o) COMMON) } .common.excl : { *(COMMON) } }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %tfile0.o %tfile1.o %tfile2.o
# RUN: llvm-readobj -S --symbols %t1 | FileCheck %s

# Commons from file0 and file1 are not excluded, so they must be in .common.incl
# Commons from file2 are excluded from the first rule and should be caught by
# the second in .common.excl
# CHECK:       Section {
# CHECK:         Index:
# CHECK:         Name: .common.incl
# CHECK-NEXT:    Type: SHT_NOBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x8
# CHECK-NEXT:    Offset: 0x
# CHECK-NEXT:    Size: 16
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 8
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }
# CHECK:       Section {
# CHECK:         Index:
# CHECK:         Name: .common.excl
# CHECK-NEXT:    Type: SHT_NOBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x20
# CHECK-NEXT:    Offset: 0x
# CHECK-NEXT:    Size: 48
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 16
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }
# CHECK:       Symbol {
# CHECK:         Name: common_multiple
# CHECK-NEXT:    Value: 0x20
# CHECK-NEXT:    Size: 32
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common.excl
# CHECK-NEXT:  }
# CHECK:       Symbol {
# CHECK:         Name: common_uniq_0
# CHECK-NEXT:    Value: 0x8
# CHECK-NEXT:    Size: 4
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common.incl
# CHECK-NEXT:  }
# CHECK:       Symbol {
# CHECK:         Name: common_uniq_1
# CHECK-NEXT:    Value: 0x10
# CHECK-NEXT:    Size: 8
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common.incl
# CHECK-NEXT:  }
# CHECK:       Symbol {
# CHECK:         Name: common_uniq_2
# CHECK-NEXT:    Value: 0x40
# CHECK-NEXT:    Size: 16
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common.excl
# CHECK-NEXT:  }

.globl _start
_start:
  jmp _start

.comm common_uniq_0,4,4
.comm common_multiple,8,8
