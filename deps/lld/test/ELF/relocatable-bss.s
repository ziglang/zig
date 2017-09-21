# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld -r %t1.o -o %t
# RUN: llvm-readobj -file-headers -sections -program-headers -symbols -r %t | FileCheck %s

## We check here that .bss does not occupy the space in file.
## If it would, the SectionHeaderOffset would have offset about 5 megabytes.
# CHECK:       ElfHeader {
# CHECK-NEXT:  Ident {
# CHECK-NEXT:    Magic: (7F 45 4C 46)
# CHECK-NEXT:    Class: 64-bit
# CHECK-NEXT:    DataEncoding: LittleEndian
# CHECK-NEXT:    FileVersion: 1
# CHECK-NEXT:    OS/ABI: SystemV
# CHECK-NEXT:    ABIVersion: 0
# CHECK-NEXT:    Unused: (00 00 00 00 00 00 00)
# CHECK-NEXT:  }
# CHECK-NEXT:  Type: Relocatable
# CHECK-NEXT:  Machine: EM_X86_64
# CHECK-NEXT:  Version:
# CHECK-NEXT:  Entry:
# CHECK-NEXT:   ProgramHeaderOffset:
# CHECK-NEXT:   SectionHeaderOffset: 0xD8
# CHECK-NEXT:  Flags [
# CHECK-NEXT:  ]
# CHECK-NEXT:  HeaderSize:
# CHECK-NEXT:  ProgramHeaderEntrySize:
# CHECK-NEXT:  ProgramHeaderCount:
# CHECK-NEXT:  SectionHeaderEntrySize:
# CHECK-NEXT:  SectionHeaderCount:
# CHECK-NEXT:  StringTableSectionIndex:
# CHECK-NEXT:  }

.text
.globl _start
_start:
 nop

.bss
 .space 5242880
