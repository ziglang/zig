# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "MEMORY {                                   \
# RUN:   AX (ax)   : ORIGIN = 0x2000, LENGTH = 0x100   \
# RUN:   AW (aw)   : ORIGIN = 0x3000, LENGTH = 0x100   \
# RUN:   FLASH (ax) : ORIGIN = 0x6000, LENGTH = 0x100   \
# RUN:   RAM (aw)   : ORIGIN = 0x7000, LENGTH = 0x100 } \
# RUN: SECTIONS {                                       \
# RUN:  .foo1 : { *(.foo1) } > AX AT>FLASH             \
# RUN:  .foo2 : { *(.foo2) } > AX                      \
# RUN:  .bar1 : { *(.bar1) } > AW AT> RAM              \
# RUN:  .bar2 : { *(.bar2) } > AW AT > RAM             \
# RUN:  .bar3 : { *(.bar3) } > AW AT >RAM              \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-readobj -program-headers %t2 | FileCheck %s
# RUN: llvm-objdump -section-headers %t2 | FileCheck %s --check-prefix=SECTIONS

# CHECK:      ProgramHeaders [
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD
# CHECK-NEXT:     Offset: 0x1000
# CHECK-NEXT:     VirtualAddress: 0x2000
# CHECK-NEXT:     PhysicalAddress: 0x6000
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
# CHECK-NEXT:     Offset: 0x2000
# CHECK-NEXT:     VirtualAddress: 0x3000
# CHECK-NEXT:     PhysicalAddress: 0x7000
# CHECK-NEXT:     FileSize: 24
# CHECK-NEXT:     MemSize: 24
# CHECK-NEXT:     Flags [
# CHECK-NEXT:       PF_R
# CHECK-NEXT:       PF_W
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 4096
# CHECK-NEXT:   }

# SECTIONS:      Sections:
# SECTIONS-NEXT: Idx Name          Size      Address
# SECTIONS-NEXT:   0               00000000 0000000000000000
# SECTIONS-NEXT:   1 .foo1         00000008 0000000000002000
# SECTIONS-NEXT:   2 .foo2         00000008 0000000000002008
# SECTIONS-NEXT:   3 .text         00000000 0000000000002010
# SECTIONS-NEXT:   4 .bar1         00000008 0000000000003000
# SECTIONS-NEXT:   5 .bar2         00000008 0000000000003008
# SECTIONS-NEXT:   6 .bar3         00000008 0000000000003010
  
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "MEMORY {                                            \
# RUN:   FLASH (ax) : ORIGIN = 0x2000, LENGTH = 0x100            \
# RUN:   RAM (aw)   : ORIGIN = 0x5000, LENGTH = 0x100 }          \
# RUN: SECTIONS {                                                \
# RUN:  .foo1 : AT(0x500) { *(.foo1) } > FLASH AT>FLASH          \
# RUN: }" > %t2.script
# RUN: not ld.lld %t --script %t2.script -o %t2 2>&1 | \
# RUN:   FileCheck %s --check-prefix=ERR
# ERR: error: section can't have both LMA and a load region

.section .foo1, "ax"
.quad 0

.section .foo2, "ax"
.quad 0

.section .bar1, "aw"
.quad 0

.section .bar2, "aw"
.quad 0

.section .bar3, "aw"
.quad 0
