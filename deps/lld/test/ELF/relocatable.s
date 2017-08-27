# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/relocatable.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/relocatable2.s -o %t3.o
# RUN: ld.lld -r %t1.o %t2.o %t3.o -o %t
# RUN: llvm-readobj -file-headers -sections -program-headers -symbols -r %t | FileCheck %s
# RUN: llvm-objdump -s -d %t | FileCheck -check-prefix=CHECKTEXT %s

## Test --relocatable alias
# RUN: ld.lld --relocatable %t1.o %t2.o %t3.o -o %t
# RUN: llvm-readobj -file-headers -sections -program-headers -symbols -r %t | FileCheck %s
# RUN: llvm-objdump -s -d %t | FileCheck -check-prefix=CHECKTEXT %s

## Verify that we can use our relocation output as input to produce executable
# RUN: ld.lld -e main %t -o %texec
# RUN: llvm-readobj -file-headers %texec | FileCheck -check-prefix=CHECKEXE %s

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
# CHECK-NEXT:  Version: 1
# CHECK-NEXT:  Entry: 0x0
# CHECK-NEXT:  ProgramHeaderOffset: 0x0
# CHECK-NEXT:  SectionHeaderOffset:
# CHECK-NEXT:  Flags [
# CHECK-NEXT:  ]
# CHECK-NEXT:  HeaderSize: 64
# CHECK-NEXT:  ProgramHeaderEntrySize: 0
# CHECK-NEXT:  ProgramHeaderCount: 0
# CHECK-NEXT:  SectionHeaderEntrySize: 64
# CHECK-NEXT:  SectionHeaderCount: 7
# CHECK-NEXT:  StringTableSectionIndex: 5
# CHECK-NEXT:  }

# CHECK:       Relocations [
# CHECK-NEXT:  Section ({{.*}}) .rela.text {
# CHECK-NEXT:    0x3 R_X86_64_32S x 0x0
# CHECK-NEXT:    0xE R_X86_64_32S y 0x0
# CHECK-NEXT:    0x23 R_X86_64_32S xx 0x0
# CHECK-NEXT:    0x2E R_X86_64_32S yy 0x0
# CHECK-NEXT:    0x43 R_X86_64_32S xxx 0x0
# CHECK-NEXT:    0x4E R_X86_64_32S yyy 0x0
# CHECK-NEXT:  }

# CHECKTEXT:      Disassembly of section .text:
# CHECKTEXT-NEXT: main:
# CHECKTEXT-NEXT: 0: c7 04 25 00 00 00 00 05 00 00 00 movl $5, 0
# CHECKTEXT-NEXT: b: c7 04 25 00 00 00 00 07 00 00 00 movl $7, 0
# CHECKTEXT:      foo:
# CHECKTEXT-NEXT: 20: c7 04 25 00 00 00 00 01 00 00 00 movl $1, 0
# CHECKTEXT-NEXT: 2b: c7 04 25 00 00 00 00 02 00 00 00 movl $2, 0
# CHECKTEXT:      bar:
# CHECKTEXT-NEXT: 40: c7 04 25 00 00 00 00 08 00 00 00 movl $8, 0
# CHECKTEXT-NEXT: 4b: c7 04 25 00 00 00 00 09 00 00 00 movl $9, 0

# CHECKEXE:       Format: ELF64-x86-64
# CHECKEXE-NEXT:  Arch: x86_64
# CHECKEXE-NEXT:  AddressSize: 64bit
# CHECKEXE-NEXT:  LoadName:
# CHECKEXE-NEXT:  ElfHeader {
# CHECKEXE-NEXT:    Ident {
# CHECKEXE-NEXT:      Magic: (7F 45 4C 46)
# CHECKEXE-NEXT:      Class: 64-bit
# CHECKEXE-NEXT:      DataEncoding: LittleEndian
# CHECKEXE-NEXT:      FileVersion: 1
# CHECKEXE-NEXT:      OS/ABI: SystemV (0x0)
# CHECKEXE-NEXT:      ABIVersion: 0
# CHECKEXE-NEXT:      Unused: (00 00 00 00 00 00 00)
# CHECKEXE-NEXT:    }
# CHECKEXE-NEXT:    Type: Executable
# CHECKEXE-NEXT:    Machine: EM_X86_64
# CHECKEXE-NEXT:    Version: 1
# CHECKEXE-NEXT:    Entry: 0x201000
# CHECKEXE-NEXT:    ProgramHeaderOffset: 0x40
# CHECKEXE-NEXT:    SectionHeaderOffset: 0x11F8
# CHECKEXE-NEXT:    Flags [
# CHECKEXE-NEXT:    ]
# CHECKEXE-NEXT:    HeaderSize: 64
# CHECKEXE-NEXT:    ProgramHeaderEntrySize: 56
# CHECKEXE-NEXT:    ProgramHeaderCount: 5
# CHECKEXE-NEXT:    SectionHeaderEntrySize: 64
# CHECKEXE-NEXT:    SectionHeaderCount: 7
# CHECKEXE-NEXT:    StringTableSectionIndex: 5
# CHECKEXE-NEXT:  }

.text
.type x,@object
.bss
.globl x
.align 4
x:
.long 0
.size x, 4
.type y,@object
.globl y
.align 4
y:
.long 0
.size y, 4

.text
.globl main
.align 16, 0x90
.type main,@function
main:
movl $5, x
movl $7, y

blah:
goo:
abs = 42
