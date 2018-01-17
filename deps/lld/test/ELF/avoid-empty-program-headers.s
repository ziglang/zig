// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld %t -o %tout
// RUN: llvm-readobj -program-headers %tout | FileCheck %s

.global _start
_start:
        retq

.section .tbss,"awT",@nobits
        .zero 4
// FIXME: Test that we don't create unecessary empty PT_LOAD and PT_GNU_RELRO
// for the .tbss section.

// CHECK:      ProgramHeaders [
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_PHDR (0x6)
// CHECK-NEXT:     Offset: 0x40
// CHECK-NEXT:     VirtualAddress: 0x200040
// CHECK-NEXT:     PhysicalAddress: 0x200040
// CHECK-NEXT:     FileSize: 280
// CHECK-NEXT:     MemSize: 280
// CHECK-NEXT:     Flags [ (0x4)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 8
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_LOAD (0x1)
// CHECK-NEXT:     Offset: 0x0
// CHECK-NEXT:     VirtualAddress: 0x200000
// CHECK-NEXT:     PhysicalAddress: 0x200000
// CHECK-NEXT:     FileSize: 344
// CHECK-NEXT:     MemSize: 344
// CHECK-NEXT:     Flags [ (0x4)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 4096
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_LOAD (0x1)
// CHECK-NEXT:     Offset: 0x1000
// CHECK-NEXT:     VirtualAddress: 0x201000
// CHECK-NEXT:     PhysicalAddress: 0x201000
// CHECK-NEXT:     FileSize: 4096
// CHECK-NEXT:     MemSize: 4096
// CHECK-NEXT:     Flags [ (0x5)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:       PF_X (0x1)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 4096
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_TLS (0x7)
// CHECK-NEXT:     Offset: 0x2000
// CHECK-NEXT:     VirtualAddress: 0x201001
// CHECK-NEXT:     PhysicalAddress: 0x201001
// CHECK-NEXT:     FileSize: 0
// CHECK-NEXT:     MemSize: 4
// CHECK-NEXT:     Flags [ (0x4)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 1
// CHECK-NEXT:   }
// CHECK-NEXT:   ProgramHeader {
// CHECK-NEXT:     Type: PT_GNU_STACK (0x6474E551)
// CHECK-NEXT:     Offset: 0x0
// CHECK-NEXT:     VirtualAddress: 0x0
// CHECK-NEXT:     PhysicalAddress: 0x0
// CHECK-NEXT:     FileSize: 0
// CHECK-NEXT:     MemSize: 0
// CHECK-NEXT:     Flags [ (0x6)
// CHECK-NEXT:       PF_R (0x4)
// CHECK-NEXT:       PF_W (0x2)
// CHECK-NEXT:     ]
// CHECK-NEXT:     Alignment: 0
// CHECK-NEXT:   }
// CHECK-NEXT: ]
