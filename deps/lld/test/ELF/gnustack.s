# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1

# RUN: ld.lld %t1 -z execstack -o %t
# RUN: llvm-readobj --program-headers -S %t | FileCheck --check-prefix=RWX %s

# RUN: ld.lld %t1 -o %t
# RUN: llvm-readobj --program-headers -S %t | FileCheck --check-prefix=RW %s

# RUN: ld.lld %t1 -o %t -z noexecstack
# RUN: llvm-readobj --program-headers -S %t | FileCheck --check-prefix=RW %s

# RW:      Type: PT_GNU_STACK
# RW-NEXT: Offset: 0x0
# RW-NEXT: VirtualAddress: 0x0
# RW-NEXT: PhysicalAddress: 0x0
# RW-NEXT: FileSize: 0
# RW-NEXT: MemSize: 0
# RW-NEXT: Flags [
# RW-NEXT:   PF_R
# RW-NEXT:   PF_W
# RW-NEXT: ]
# RW-NEXT: Alignment: 0

# RWX:      Type: PT_GNU_STACK
# RWX-NEXT: Offset: 0x0
# RWX-NEXT: VirtualAddress: 0x0
# RWX-NEXT: PhysicalAddress: 0x0
# RWX-NEXT: FileSize: 0
# RWX-NEXT: MemSize: 0
# RWX-NEXT: Flags [
# RWX-NEXT:   PF_R
# RWX-NEXT:   PF_W
# RWX-NEXT:   PF_X
# RWX-NEXT: ]
# RWX-NEXT: Alignment: 0

.globl _start
_start:
