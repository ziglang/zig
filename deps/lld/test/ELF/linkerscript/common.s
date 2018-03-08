# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { . = SIZEOF_HEADERS; .common : { *(COMMON) } }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-readobj -s -t %t1 | FileCheck %s

# CHECK:       Section {
# CHECK:         Index:
# CHECK:         Name: .common
# CHECK-NEXT:    Type: SHT_NOBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x200
# CHECK-NEXT:    Offset: 0x
# CHECK-NEXT:    Size: 384
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 256
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }
# CHECK:       Symbol {
# CHECK:         Name: q1
# CHECK-NEXT:    Value: 0x200
# CHECK-NEXT:    Size: 128
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common
# CHECK-NEXT:  }
# CHECK-NEXT:  Symbol {
# CHECK-NEXT:    Name: q2
# CHECK-NEXT:    Value: 0x300
# CHECK-NEXT:    Size: 128
# CHECK-NEXT:    Binding: Global
# CHECK-NEXT:    Type: Object
# CHECK-NEXT:    Other: 0
# CHECK-NEXT:    Section: .common
# CHECK-NEXT:  }

.globl _start
_start:
  jmp _start

.comm q1,128,8
.comm q2,128,256
