# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

################################################################################
## Test that non-alloc section .foo can be assigned to a segment. Check that
## the values of the offset and file size of this segment's PHDR are correct.
##
## This functionality allows non-alloc metadata, which is not required at
## run-time, to be added to a custom segment in a file. This metadata may be
## read/edited by tools/loader using the values of the offset and file size from
## the custom segment's PHDR. This is particularly important if section headers
## have been stripped.
# RUN: echo "PHDRS {text PT_LOAD; foo 0x12345678;} \
# RUN:       SECTIONS { \
# RUN:           .text : {*(.text .text*)} :text \
# RUN:           .foo : {*(.foo)} :foo \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readelf -S -l %t | FileCheck %s
# RUN: llvm-readobj -l %t | FileCheck --check-prefix=PHDR %s

# CHECK: Program Headers:
# CHECK-NEXT:  Type
# CHECK-NEXT:  LOAD
# CHECK-NEXT:  <unknown>: 0x12345678

# CHECK:      Section to Segment mapping:
# CHECK-NEXT:  Segment Sections...
# CHECK-NEXT:   00     .text
# CHECK-NEXT:   01     .foo

# PHDR: Type:  (0x12345678)
# PHDR-NEXT: Offset: 0x1004
# PHDR-NEXT: VirtualAddress
# PHDR-NEXT: PhysicalAddress
# PHDR-NEXT: FileSize: 4

.global _start
_start:
 nop

.section .foo
 .align 4
 .long 0
