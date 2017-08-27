# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:   .aaa 0x2000 : { *(.aaa) } \
# RUN:   .bbb 0x1 ? 0x3000 : 0x4000 : { *(.bbb) } \
# RUN:   .ccc ALIGN(CONSTANT(MAXPAGESIZE)) + (. & (CONSTANT(MAXPAGESIZE) - 1)) : { *(.ccc) } \
# RUN:   .ddd 0x5001 : { *(.ddd) } \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %tout
# RUN: llvm-readobj -s %tout | FileCheck %s

## Check:
## 1) Simple constant as address.
## 2) That something that contains ":" character, like ternary
##    operator works as expression.
## 3) That complex expressions work.
## 4) That section alignment still applied to explicitly specified address.

#CHECK:Sections [
#CHECK:  Section {
#CHECK:    Index: 0
#CHECK:    Name:
#CHECK:    Type: SHT_NULL
#CHECK:    Flags [
#CHECK:    ]
#CHECK:    Address: 0x0
#CHECK:    Offset: 0x0
#CHECK:    Size: 0
#CHECK:    Link: 0
#CHECK:    Info: 0
#CHECK:    AddressAlignment: 0
#CHECK:    EntrySize: 0
#CHECK:  }
#CHECK:  Section {
#CHECK:    Index: 1
#CHECK:    Name: .aaa
#CHECK:    Type: SHT_PROGBITS
#CHECK:    Flags [
#CHECK:      SHF_ALLOC
#CHECK:    ]
#CHECK:    Address: 0x2000
#CHECK:    Offset: 0x1000
#CHECK:    Size: 8
#CHECK:    Link: 0
#CHECK:    Info: 0
#CHECK:    AddressAlignment: 1
#CHECK:    EntrySize: 0
#CHECK:  }
#CHECK:  Section {
#CHECK:    Index: 2
#CHECK:    Name: .bbb
#CHECK:    Type: SHT_PROGBITS
#CHECK:    Flags [
#CHECK:      SHF_ALLOC
#CHECK:    ]
#CHECK:    Address: 0x3000
#CHECK:    Offset: 0x2000
#CHECK:    Size: 8
#CHECK:    Link: 0
#CHECK:    Info: 0
#CHECK:    AddressAlignment: 1
#CHECK:    EntrySize: 0
#CHECK:  }
#CHECK:  Section {
#CHECK:    Index: 3
#CHECK:    Name: .ccc
#CHECK:    Type: SHT_PROGBITS
#CHECK:    Flags [
#CHECK:      SHF_ALLOC
#CHECK:    ]
#CHECK:    Address: 0x4008
#CHECK:    Offset: 0x3008
#CHECK:    Size: 8
#CHECK:    Link: 0
#CHECK:    Info: 0
#CHECK:    AddressAlignment: 1
#CHECK:    EntrySize: 0
#CHECK:  }
#CHECK:  Section {
#CHECK:    Index: 4
#CHECK:    Name: .ddd
#CHECK:    Type: SHT_PROGBITS
#CHECK:    Flags [
#CHECK:      SHF_ALLOC
#CHECK:    ]
#CHECK:    Address: 0x5010
#CHECK:    Offset: 0x4010
#CHECK:    Size: 8
#CHECK:    Link: 0
#CHECK:    Info: 0
#CHECK:    AddressAlignment: 16
#CHECK:    EntrySize: 0
#CHECK:  }

.globl _start
_start:
nop

.section .aaa, "a"
.quad 0

.section .bbb, "a"
.quad 0

.section .ccc, "a"
.quad 0

.section .ddd, "a"
.align 16
.quad 0
