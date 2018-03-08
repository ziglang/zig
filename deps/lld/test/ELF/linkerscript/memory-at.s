# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "MEMORY {                                   \
# RUN:   FLASH (rx) : ORIGIN = 0x1000, LENGTH = 0x100   \
# RUN:   RAM (rwx)  : ORIGIN = 0x2000, LENGTH = 0x100 } \
# RUN: SECTIONS {                                       \
# RUN:  .text : { *(.text*) } > FLASH                   \
# RUN:  __etext = .;                                    \
# RUN:  .data : AT (__etext) { *(.data*) } > RAM        \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-readobj -program-headers %t2 | FileCheck %s

# CHECK:      ProgramHeaders [
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x1000
# CHECK-NEXT:     VirtualAddress: 0x1000
# CHECK-NEXT:     PhysicalAddress: 0x1000
# CHECK-NEXT:     FileSize: 8
# CHECK-NEXT:     MemSize: 8
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_X
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment:
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x2000
# CHECK-NEXT:     VirtualAddress: 0x2000
# CHECK-NEXT:     PhysicalAddress: 0x1008
# CHECK-NEXT:     FileSize: 8
# CHECK-NEXT:     MemSize: 8
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_W
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment:
# CHECK-NEXT:   }

.section .text, "ax"
.quad 0

.section .data, "aw"
.quad 0
