# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld -z stack-size=0x1000 %t -o %t1
# RUN: llvm-readobj -program-headers %t1 | FileCheck %s -check-prefix=CHECK1

# RUN: ld.lld -z stack-size=0 %t -o %t2
# RUN: llvm-readobj -program-headers %t2 | FileCheck %s -check-prefix=CHECK2

.global _start
_start:
  nop

# CHECK1:     Type: PT_GNU_STACK (0x6474E551)
# CHECK1-NEXT:     Offset: 0x0
# CHECK1-NEXT:     VirtualAddress: 0x0
# CHECK1-NEXT:     PhysicalAddress: 0x0
# CHECK1-NEXT:     FileSize: 0
# CHECK1-NEXT:     MemSize: 4096
# CHECK1-NEXT:     Flags [ (0x6)
# CHECK1-NEXT:       PF_R (0x4)
# CHECK1-NEXT:       PF_W (0x2)
# CHECK1-NEXT:     ]

# CHECK2:     Type: PT_GNU_STACK (0x6474E551)
# CHECK2-NEXT:     Offset: 0x0
# CHECK2-NEXT:     VirtualAddress: 0x0
# CHECK2-NEXT:     PhysicalAddress: 0x0
# CHECK2-NEXT:     FileSize: 0
# CHECK2-NEXT:     MemSize: 0
# CHECK2-NEXT:     Flags [ (0x6)
# CHECK2-NEXT:       PF_R (0x4)
# CHECK2-NEXT:       PF_W (0x2)
# CHECK2-NEXT:     ]
