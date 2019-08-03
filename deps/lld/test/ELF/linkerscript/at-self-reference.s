# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:  . = 0x1000; \
# RUN:  .aaa : AT(ADDR(.aaa)) { *(.aaa) } \
# RUN:  .bbb : AT(ADDR(.bbb)) { *(.bbb) } \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-readobj -l %t2 | FileCheck %s

# CHECK:      ProgramHeaders [
# CHECK-NEXT:  ProgramHeader {
# CHECK-NEXT:    Type: PT_LOAD (0x1)
# CHECK-NEXT:    Offset: 0x1000
# CHECK-NEXT:    VirtualAddress: 0x1000
# CHECK-NEXT:    PhysicalAddress: 0x1000
# CHECK-NEXT:    FileSize: 3
# CHECK-NEXT:    MemSize: 3
# CHECK-NEXT:    Flags [ (0x5)
# CHECK-NEXT:      PF_R (0x4)
# CHECK-NEXT:      PF_X (0x1)
# CHECK-NEXT:    ]
# CHECK-NEXT:    Alignment: 4096
# CHECK-NEXT:  }
# CHECK-NEXT:  ProgramHeader {
# CHECK-NEXT:    Type: PT_LOAD (0x1)
# CHECK-NEXT:    Offset: 0x1008
# CHECK-NEXT:    VirtualAddress: 0x1008
# CHECK-NEXT:    PhysicalAddress: 0x1008
# CHECK-NEXT:    FileSize: 9
# CHECK-NEXT:    MemSize: 9
# CHECK-NEXT:    Flags [ (0x5)
# CHECK-NEXT:      PF_R (0x4)
# CHECK-NEXT:      PF_X (0x1)
# CHECK-NEXT:    ]
# CHECK-NEXT:    Alignment: 4096
# CHECK-NEXT:  }
# CHECK-NEXT:  ProgramHeader {
# CHECK-NEXT:    Type: PT_GNU_STACK (0x6474E551)
# CHECK-NEXT:    Offset: 0x0
# CHECK-NEXT:    VirtualAddress: 0x0
# CHECK-NEXT:    PhysicalAddress: 0x0
# CHECK-NEXT:    FileSize: 0
# CHECK-NEXT:    MemSize: 0
# CHECK-NEXT:    Flags [ (0x6)
# CHECK-NEXT:      PF_R (0x4)
# CHECK-NEXT:      PF_W (0x2)
# CHECK-NEXT:    ]
# CHECK-NEXT:    Alignment: 0
# CHECK-NEXT:  }
# CHECK-NEXT:]

.global _start
_start:
 nop


.section .aaa, "a"
.asciz "aa"

.section .bbb, "a"
.align 8
.quad 0
