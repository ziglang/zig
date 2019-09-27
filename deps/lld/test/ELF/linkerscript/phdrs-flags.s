# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "PHDRS {all PT_LOAD FILEHDR PHDRS FLAGS (1 | 1 + 0x1);} \
# RUN:       SECTIONS { \
# RUN:           . = 0x10000200; \
# RUN:           .text : {*(.text*)} :all \
# RUN:           .foo : {*(.foo.*)} :all \
# RUN:           .data : {*(.data.*)} :all}" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-readobj -l %t1 | FileCheck %s

# RUN: echo "PHDRS {all PT_LOAD FILEHDR PHDRS FLAGS (0x1);} \
# RUN:       SECTIONS { \
# RUN:           . = 0x10000200; \
# RUN:           .text : {*(.text*)} :all \
# RUN:           .foo : {*(.foo.*)}  \
# RUN:           .data : {*(.data.*)} }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-readobj -l %t1 | FileCheck --check-prefix=DEFHDR %s

# CHECK:     ProgramHeaders [
# CHECK-NEXT:  ProgramHeader {
# CHECK-NEXT:    Type: PT_LOAD (0x1)
# CHECK-NEXT:    Offset: 0x0
# CHECK-NEXT:    VirtualAddress: 0x10000000
# CHECK-NEXT:    PhysicalAddress: 0x10000000
# CHECK-NEXT:    FileSize: 521
# CHECK-NEXT:    MemSize: 521
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      PF_W (0x2)
# CHECK-NEXT:      PF_X (0x1)
# CHECK-NEXT:    ]

# DEFHDR:     ProgramHeaders [
# DEFHDR-NEXT:  ProgramHeader {
# DEFHDR-NEXT:    Type: PT_LOAD (0x1)
# DEFHDR-NEXT:    Offset: 0x0
# DEFHDR-NEXT:    VirtualAddress: 0x10000000
# DEFHDR-NEXT:    PhysicalAddress: 0x10000000
# DEFHDR-NEXT:    FileSize: 521
# DEFHDR-NEXT:    MemSize: 521
# DEFHDR-NEXT:    Flags [ (0x1)
# DEFHDR-NEXT:      PF_X (0x1)
# DEFHDR-NEXT:    ]
# DEFHDR-NEXT:    Alignment: 4096
# DEFHDR-NEXT:  }

.global _start
_start:
 nop

.section .foo.1,"a"
foo1:
 .long 0

.section .foo.2,"aw"
foo2:
 .long 0
