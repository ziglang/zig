# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:        .data_noload_a (NOLOAD) : { *(.data_noload_a) } \
# RUN:        .data_noload_b (0x10000) (NOLOAD) : { *(.data_noload_b) } \
# RUN:        .text (0x20000) : { *(.text) } };" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj --sections -l  %t | FileCheck %s

# CHECK:      Section {
# CHECK:        Index: 1
# CHECK-NEXT:   Name: .data_noload_a
# CHECK-NEXT:   Type: SHT_NOBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x0
# CHECK-NEXT:   Offset: 0xE8
# CHECK-NEXT:   Size: 4096
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 1
# CHECK-NEXT:   EntrySize: 0
# CHECK-NEXT: }
# CHECK-NEXT: Section {
# CHECK-NEXT:   Index: 2
# CHECK-NEXT:   Name: .data_noload_b
# CHECK-NEXT:   Type: SHT_NOBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x10000
# CHECK-NEXT:   Offset: 0xE8
# CHECK-NEXT:   Size: 4096
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 1
# CHECK-NEXT:   EntrySize: 0
# CHECK-NEXT: }
# CHECK:      ProgramHeader {
# CHECK-NEXT:   Type: PT_LOAD (0x1)
# CHECK-NEXT:   Offset: 0x1000
# CHECK-NEXT:   VirtualAddress: 0x20000
# CHECK-NEXT:   PhysicalAddress: 0x20000
# CHECK-NEXT:   FileSize: 1
# CHECK-NEXT:   MemSize: 1
# CHECK-NEXT:   Flags [ (0x5)
# CHECK-NEXT:     PF_R (0x4)
# CHECK-NEXT:     PF_X (0x1)
# CHECK-NEXT:   ]
# CHECK-NEXT:   Alignment: 4096
# CHECK-NEXT: }

.section .text,"ax",@progbits
  nop

.section .data_noload_a,"aw",@progbits
.zero 4096

.section .data_noload_b,"aw",@progbits
.zero 4096
