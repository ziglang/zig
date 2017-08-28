# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:  .bss : { *(.bss) } \
# RUN:  .data : { *(.data) } \
# RUN:  .text : { *(.text) } }" > %t.script
# RUN: ld.lld %t.o --script %t.script -o %t
# RUN: llvm-readobj -sections -symbols %t | FileCheck %s

# CHECK:      Sections [
# CHECK-NEXT:  Section {
# CHECK-NEXT:    Index: 0
# CHECK-NEXT:    Name:  (0)
# CHECK-NEXT:    Type: SHT_NULL
# CHECK-NEXT:    Flags [
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x0
# CHECK-NEXT:    Offset: 0x0
# CHECK-NEXT:    Size: 0
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 0
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }
# CHECK-NEXT:  Section {
# CHECK-NEXT:    Index: 1
# CHECK-NEXT:    Name: .bss
# CHECK-NEXT:    Type: SHT_NOBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x158
# CHECK-NEXT:    Offset: 0x158
# CHECK-NEXT:    Size: 6
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 1
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }
# CHECK-NEXT:  Section {
# CHECK-NEXT:    Index: 2
# CHECK-NEXT:    Name: .data
# CHECK-NEXT:    Type: SHT_PROGBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x15E
# CHECK-NEXT:    Offset: 0x15E
# CHECK-NEXT:    Size: 2
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 1
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }
# CHECK-NEXT:  Section {
# CHECK-NEXT:    Index: 3
# CHECK-NEXT:    Name: .text
# CHECK-NEXT:    Type: SHT_PROGBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_EXECINSTR
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x160
# CHECK-NEXT:    Offset: 0x160
# CHECK-NEXT:    Size: 1
# CHECK-NEXT:    Link: 0
# CHECK-NEXT:    Info: 0
# CHECK-NEXT:    AddressAlignment: 4
# CHECK-NEXT:    EntrySize: 0
# CHECK-NEXT:  }

.global _start
.text
_start:
 nop
.data
 .word 1
.bss
 .space 6
