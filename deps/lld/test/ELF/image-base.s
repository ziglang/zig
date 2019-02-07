# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld -image-base=0x1000000 %t -o %t1
# RUN: llvm-readobj -program-headers %t1 | FileCheck %s

# RUN: not ld.lld -image-base=ABC %t -o %t1 2>&1 | FileCheck --check-prefix=ERR %s
# ERR: error: -image-base: number expected, but got ABC

# RUN: ld.lld -image-base=0x1000 -z max-page-size=0x2000 %t -o %t1 2>&1 | FileCheck --check-prefix=WARN %s
# WARN: warning: -image-base: address isn't multiple of page size: 0x1000

# Check alias.
# RUN: ld.lld -image-base 0x1000000 %t -o %t1
# RUN: llvm-readobj -program-headers %t1 | FileCheck %s

.global _start
_start:
  nop

# CHECK:      ProgramHeaders [
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_PHDR (0x6)
# CHECK-NEXT:     Offset: 0x40
# CHECK-NEXT:     VirtualAddress: 0x1000040
# CHECK-NEXT:     PhysicalAddress: 0x1000040
# CHECK-NEXT:     FileSize: 224
# CHECK-NEXT:     MemSize: 224
# CHECK-NEXT:     Flags [ (0x4)
# CHECK-NEXT:       PF_R (0x4)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 8
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD (0x1)
# CHECK-NEXT:     Offset: 0x0
# CHECK-NEXT:     VirtualAddress: 0x1000000
# CHECK-NEXT:     PhysicalAddress: 0x1000000
# CHECK-NEXT:     FileSize: 288
# CHECK-NEXT:     MemSize: 288
# CHECK-NEXT:     Flags [ (0x4)
# CHECK-NEXT:       PF_R (0x4)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 4096
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_LOAD (0x1)
# CHECK-NEXT:     Offset: 0x1000
# CHECK-NEXT:     VirtualAddress: 0x1001000
# CHECK-NEXT:     PhysicalAddress: 0x1001000
# CHECK-NEXT:     FileSize: 4096
# CHECK-NEXT:     MemSize: 4096
# CHECK-NEXT:     Flags [ (0x5)
# CHECK-NEXT:       PF_R (0x4)
# CHECK-NEXT:       PF_X (0x1)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 4096
# CHECK-NEXT:   }
# CHECK-NEXT:   ProgramHeader {
# CHECK-NEXT:     Type: PT_GNU_STACK (0x6474E551)
# CHECK-NEXT:     Offset: 0x0
# CHECK-NEXT:     VirtualAddress: 0x0
# CHECK-NEXT:     PhysicalAddress: 0x0
# CHECK-NEXT:     FileSize: 0
# CHECK-NEXT:     MemSize: 0
# CHECK-NEXT:     Flags [ (0x6)
# CHECK-NEXT:       PF_R (0x4)
# CHECK-NEXT:       PF_W (0x2)
# CHECK-NEXT:     ]
# CHECK-NEXT:     Alignment: 0
# CHECK-NEXT:   }
