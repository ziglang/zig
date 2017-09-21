# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: ld.lld %t -o %t.out
# RUN: llvm-readobj --program-headers %t.out | FileCheck %s

# CHECK:      ProgramHeader {
# CHECK:        Type: PT_OPENBSD_RANDOMIZE (0x65A3DBE6)
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   VirtualAddress:
# CHECK-NEXT:   PhysicalAddress:
# CHECK-NEXT:   FileSize: 8
# CHECK-NEXT:   MemSize: 8
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     PF_R (0x4)
# CHECK-NEXT:   ]
# CHECK-NEXT:   Alignment: 1
# CHECK-NEXT: }

.section .openbsd.randomdata, "a"
.quad 0
