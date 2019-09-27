# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# Test that we warn when a page size is set and paging is disabled by -n or -N.

# RUN: ld.lld -z max-page-size=0x10 -z common-page-size=0x10 -N %t -o %t2 2>&1 | FileCheck --check-prefix=WARN %s
# RUN: llvm-readobj --program-headers %t2 | FileCheck --check-prefix=OMAGIC %s
# RUN: ld.lld -z max-page-size=0x10 -z common-page-size=0x10 --omagic %t -o %t2  2>&1 | FileCheck --check-prefix=WARN %s
# RUN: llvm-readobj --program-headers %t2 | FileCheck --check-prefix=OMAGIC %s

# WARN: ld.lld: warning: -z max-page-size set, but paging disabled by omagic or nmagic
# WARN-NEXT: ld.lld: warning: -z common-page-size set, but paging disabled by omagic or nmagic

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

# RUN: ld.lld -z max-page-size=0x10 -z common-page-size=0x10 -n %t -o %t3  2>&1 | FileCheck --check-prefix=WARN %s
# RUN: llvm-readobj --program-headers %t3 | FileCheck --check-prefix=NMAGIC %s
# RUN: ld.lld -z max-page-size=0x10 -z common-page-size=0x10 --nmagic %t -o %t3  2>&1 | FileCheck --check-prefix=WARN %s
# RUN: llvm-readobj --program-headers %t3 | FileCheck --check-prefix=NMAGIC %s

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
