# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
# RUN: ld.lld -z wxneeded %t -o %t.out
# RUN: llvm-readobj --program-headers %t.out | FileCheck %s

# CHECK:      ProgramHeader {
# CHECK:        Type: PT_OPENBSD_WXNEEDED (0x65A3DBE7)
# CHECK-NEXT:   Offset: 0x0
# CHECK-NEXT:   VirtualAddress: 0x0
# CHECK-NEXT:   PhysicalAddress: 0x0
# CHECK-NEXT:   FileSize: 0
# CHECK-NEXT:   MemSize: 0
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     PF_X
# CHECK-NEXT:   ]
# CHECK-NEXT:   Alignment: 0
# CHECK-NEXT: }
