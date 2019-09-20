# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: ld.lld %t -o %t1
# RUN: llvm-readobj --program-headers %t1 | FileCheck --check-prefix=ROSEGMENT %s
# RUN: ld.lld --omagic --no-omagic %t -o %t1
# RUN: llvm-readobj --program-headers %t1 | FileCheck --check-prefix=ROSEGMENT %s

# ROSEGMENT:      ProgramHeader {
# ROSEGMENT:        Type: PT_LOAD
# ROSEGMENT-NEXT:    Offset: 0x0
# ROSEGMENT-NEXT:    VirtualAddress:
# ROSEGMENT-NEXT:    PhysicalAddress:
# ROSEGMENT-NEXT:    FileSize:
# ROSEGMENT-NEXT:    MemSize:
# ROSEGMENT-NEXT:    Flags [
# ROSEGMENT-NEXT:      PF_R
# ROSEGMENT-NEXT:    ]
# ROSEGMENT-NEXT:    Alignment: 4096
# ROSEGMENT-NEXT:  }
# ROSEGMENT-NEXT:  ProgramHeader {
# ROSEGMENT-NEXT:    Type: PT_LOAD
# ROSEGMENT-NEXT:    Offset: 0x1000
# ROSEGMENT-NEXT:    VirtualAddress:
# ROSEGMENT-NEXT:    PhysicalAddress:
# ROSEGMENT-NEXT:    FileSize:
# ROSEGMENT-NEXT:    MemSize:
# ROSEGMENT-NEXT:    Flags [
# ROSEGMENT-NEXT:      PF_R
# ROSEGMENT-NEXT:      PF_X
# ROSEGMENT-NEXT:    ]
# ROSEGMENT-NEXT:    Alignment: 4096
# ROSEGMENT-NEXT:  }
# ROSEGMENT-NEXT:  ProgramHeader {
# ROSEGMENT-NEXT:    Type: PT_LOAD
# ROSEGMENT-NEXT:    Offset: 0x2000
# ROSEGMENT-NEXT:    VirtualAddress:
# ROSEGMENT-NEXT:    PhysicalAddress:
# ROSEGMENT-NEXT:    FileSize: 1
# ROSEGMENT-NEXT:    MemSize: 1
# ROSEGMENT-NEXT:    Flags [
# ROSEGMENT-NEXT:      PF_R
# ROSEGMENT-NEXT:      PF_W
# ROSEGMENT-NEXT:    ]
# ROSEGMENT-NEXT:    Alignment: 4096
# ROSEGMENT-NEXT:  }

# RUN: ld.lld -no-rosegment %t -o %t2
# RUN: llvm-readobj --program-headers %t2 | FileCheck --check-prefix=NOROSEGMENT %s

# NOROSEGMENT:     ProgramHeader {
# NOROSEGMENT:       Type: PT_LOAD
# NOROSEGMENT-NEXT:   Offset: 0x0
# NOROSEGMENT-NEXT:   VirtualAddress:
# NOROSEGMENT-NEXT:   PhysicalAddress:
# NOROSEGMENT-NEXT:   FileSize:
# NOROSEGMENT-NEXT:   MemSize:
# NOROSEGMENT-NEXT:   Flags [
# NOROSEGMENT-NEXT:     PF_R
# NOROSEGMENT-NEXT:     PF_X
# NOROSEGMENT-NEXT:   ]
# NOROSEGMENT-NEXT:   Alignment: 4096
# NOROSEGMENT-NEXT: }
# NOROSEGMENT-NEXT: ProgramHeader {
# NOROSEGMENT-NEXT:   Type: PT_LOAD
# NOROSEGMENT-NEXT:   Offset: 0x1000
# NOROSEGMENT-NEXT:   VirtualAddress:
# NOROSEGMENT-NEXT:   PhysicalAddress:
# NOROSEGMENT-NEXT:   FileSize:
# NOROSEGMENT-NEXT:   MemSize:
# NOROSEGMENT-NEXT:   Flags [
# NOROSEGMENT-NEXT:     PF_R
# NOROSEGMENT-NEXT:     PF_W
# NOROSEGMENT-NEXT:   ]
# NOROSEGMENT-NEXT:   Alignment: 4096
# NOROSEGMENT-NEXT: }
# NOROSEGMENT-NEXT: ProgramHeader {
# NOROSEGMENT-NEXT:   Type: PT_GNU_STACK

# RUN: ld.lld -N %t -o %t3
# RUN: llvm-readobj --program-headers %t3 | FileCheck --check-prefix=OMAGIC %s
# RUN: ld.lld --omagic %t -o %t3
# RUN: llvm-readobj --program-headers %t3 | FileCheck --check-prefix=OMAGIC %s

# OMAGIC:     ProgramHeader {
# OMAGIC:      Type: PT_LOAD
# OMAGIC-NEXT:   Offset: 0xE8
# OMAGIC-NEXT:   VirtualAddress:
# OMAGIC-NEXT:   PhysicalAddress:
# OMAGIC-NEXT:   FileSize:
# OMAGIC-NEXT:   MemSize:
# OMAGIC-NEXT:   Flags [
# OMAGIC-NEXT:     PF_R
# OMAGIC-NEXT:     PF_W
# OMAGIC-NEXT:     PF_X
# OMAGIC-NEXT:   ]
# OMAGIC-NEXT:   Alignment: 8
# OMAGIC-NEXT: }
# OMAGIC-NEXT: ProgramHeader {
# OMAGIC-NEXT:   Type: PT_GNU_STACK

# RUN: ld.lld -n %t -o %t4
# RUN: llvm-readobj --program-headers %t4 | FileCheck --check-prefix=NMAGIC %s
# RUN: ld.lld --nmagic %t -o %t4
# RUN: llvm-readobj --program-headers %t4 | FileCheck --check-prefix=NMAGIC %s

# NMAGIC:   ProgramHeader {
# NMAGIC-NEXT:     Type: PT_LOAD
# NMAGIC-NEXT:     Offset: 0x158
# NMAGIC-NEXT:     VirtualAddress:
# NMAGIC-NEXT:     PhysicalAddress:
# NMAGIC-NEXT:     FileSize: 1
# NMAGIC-NEXT:     MemSize: 1
# NMAGIC-NEXT:     Flags [
# NMAGIC-NEXT:       PF_R
# NMAGIC-NEXT:     ]
# NMAGIC-NEXT:     Alignment: 8
# NMAGIC-NEXT:   }
# NMAGIC-NEXT:   ProgramHeader {
# NMAGIC-NEXT:     Type: PT_LOAD
# NMAGIC-NEXT:     Offset: 0x15C
# NMAGIC-NEXT:     VirtualAddress:
# NMAGIC-NEXT:     PhysicalAddress:
# NMAGIC-NEXT:     FileSize: 2
# NMAGIC-NEXT:     MemSize: 2
# NMAGIC-NEXT:     Flags [
# NMAGIC-NEXT:       PF_R
# NMAGIC-NEXT:       PF_X
# NMAGIC-NEXT:     ]
# NMAGIC-NEXT:     Alignment: 4
# NMAGIC-NEXT:   }
# NMAGIC-NEXT:   ProgramHeader {
# NMAGIC-NEXT:     Type: PT_LOAD (0x1)
# NMAGIC-NEXT:     Offset: 0x15E
# NMAGIC-NEXT:     VirtualAddress:
# NMAGIC-NEXT:     PhysicalAddress:
# NMAGIC-NEXT:     FileSize: 1
# NMAGIC-NEXT:     MemSize: 1
# NMAGIC-NEXT:     Flags [
# NMAGIC-NEXT:       PF_R
# NMAGIC-NEXT:       PF_W
# NMAGIC-NEXT:     ]
# NMAGIC-NEXT:     Alignment: 1
# NMAGIC-NEXT:   }

.global _start
_start:
 nop

.section .ro,"a"
nop

.section .rw,"aw"
nop

.section .rx,"ax"
nop
