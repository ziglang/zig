# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:  . = 0x1000; \
# RUN:  .aaa : AT(0x2000) { *(.aaa) } \
# RUN:  .bbb : { *(.bbb) } \
# RUN:  .ccc : AT(0x3000) { *(.ccc) } \
# RUN:  .ddd : AT(0x4000) { *(.ddd) } \
# RUN:  .eee 0x5000 : AT(0x5000) { *(.eee) } \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-readobj -program-headers %t2 | FileCheck %s

# CHECK:      ProgramHeaders [
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_PHDR
# CHECK-NEXT:     Offset: 0x40
# CHECK-NEXT:     VirtualAddress: 0x40
# CHECK-NEXT:     PhysicalAddress: 0x40
# CHECK-NEXT:     FileSize:
# CHECK-NEXT:     MemSize:
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 8
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x0
# CHECK-NEXT:     VirtualAddress: 0x0
# CHECK-NEXT:     PhysicalAddress: 0x0
# CHECK-NEXT:     FileSize:
# CHECK-NEXT:     MemSize:
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_X
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment:
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x1000
# CHECK-NEXT:     VirtualAddress: 0x1000
# CHECK-NEXT:     PhysicalAddress: 0x2000
# CHECK-NEXT:     FileSize: 16
# CHECK-NEXT:     MemSize: 16
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_X
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment:
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x1010
# CHECK-NEXT:     VirtualAddress: 0x1010
# CHECK-NEXT:     PhysicalAddress: 0x3000
# CHECK-NEXT:     FileSize: 8
# CHECK-NEXT:     MemSize: 8
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_X
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 4096
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x1018
# CHECK-NEXT:     VirtualAddress: 0x1018
# CHECK-NEXT:     PhysicalAddress: 0x4000
# CHECK-NEXT:     FileSize: 8
# CHECK-NEXT:     MemSize: 8
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_X
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 4096
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x2000
# CHECK-NEXT:     VirtualAddress: 0x5000
# CHECK-NEXT:     PhysicalAddress: 0x5000
# CHECK-NEXT:     FileSize: 9
# CHECK-NEXT:     MemSize: 9
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_X
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 4096
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_GNU_STACK
# CHECK-NEXT:     Offset:
# CHECK-NEXT:     VirtualAddress: 0x0
# CHECK-NEXT:     PhysicalAddress: 0x0
# CHECK-NEXT:     FileSize:
# CHECK-NEXT:     MemSize:
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_W
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.global _start
_start:
 nop

.section .aaa, "a"
.quad 0

.section .bbb, "a"
.quad 0

.section .ccc, "a"
.quad 0

.section .ddd, "a"
.quad 0

.section .eee, "a"
.quad 0
