# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --eh-frame-hdr --section-start .text=0x1000 %t.o -o %t
# RUN: llvm-readobj -S --section-data %t | FileCheck %s

## Check we are able to handle DW_EH_PE_udata2 encoding.

# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .eh_frame_hdr
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x2000
# CHECK-NEXT:   Offset: 0x2000
# CHECK-NEXT:   Size: 20
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 4
# CHECK-NEXT:   EntrySize: 0
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 011B033B 10000000 01000000 34F2FFFF
# CHECK-NEXT:     0010: 24000000
# Header (always 4 bytes): 011B033B
#    10000000 = .eh_frame(0x2014) - .eh_frame_hdr(0x2000) - 4
#    01000000 = 1 = the number of FDE pointers in the table.
# 34F2FFFF = foo(0x1000) - 0x234(addend) - .eh_frame_hdr(0x2000)
  
# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .eh_frame
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x2014
# CHECK-NEXT:   Offset: 0x2014
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Link:
# CHECK-NEXT:   Info:
# CHECK-NEXT:   AddressAlignment:
# CHECK-NEXT:   EntrySize:
# CHECK-NEXT:   SectionData (
# CHECK-NEXT:     0000: 0C000000 00000000 01520001 010102FF
# CHECK-NEXT:     0010: 0C000000 14000000 34120000 00000000
#                                           ^
#                                           ---> ADDR(foo) + 0x234 = 0x1234

.text
.global foo
foo:
 nop

.section .eh_frame
  .long 12   # Size
  .long 0x00 # ID
  .byte 0x01 # Version.
  
  .byte 0x52 # Augmentation string: 'R','\0'
  .byte 0x00
  
  .byte 0x01
  
  .byte 0x01 # LEB128
  .byte 0x01 # LEB128

  .byte 0x02 # DW_EH_PE_udata2

  .byte 0xFF
 
  .long 0x6  # Size
  .long 0x14 # ID
  .short foo + 0x234
