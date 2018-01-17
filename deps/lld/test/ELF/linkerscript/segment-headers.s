# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { . = 0x2000; .text : AT(0x100000) { *(.text) } }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj -l %t | FileCheck %s

# CHECK: ProgramHeaders [
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD (0x1)
# CHECK-NEXT:     Offset: 0x1000
# CHECK-NEXT:     VirtualAddress: 0x2000
# CHECK-NEXT:     PhysicalAddress: 0x100000
# CHECK-NEXT:     FileSize: 1
# CHECK-NEXT:     MemSize: 1
# CHECK-NEXT:     Flags [ (0x5)
# CHECK-NEXT:       PF_R (0x4)
# CHECK-NEXT:       PF_X (0x1)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 4096
# CHECK-NEXT:   }

.section .text
.global _start

_start:
  ret
