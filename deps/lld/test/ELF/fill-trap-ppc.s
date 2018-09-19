# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.ppc64le
# RUN: llvm-readobj -program-headers %t.ppc64le | FileCheck %s
# RUN: od -Ax -t x1 -N16 -j0x10ff0 %t.ppc64le | FileCheck %s -check-prefix=LE

# RUN: llvm-mc -filetype=obj -triple=powerpc64-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.ppc64
# RUN: llvm-readobj -program-headers %t.ppc64 | FileCheck %s
# RUN: od -Ax -t x1 -N16 -j0x10ff0 %t.ppc64 | FileCheck %s -check-prefix=BE

# CHECK: ProgramHeader {
# CHECK:   Type: PT_LOAD
# CHECK:        Offset: 0x10000{{$}}
# CHECK-NEXT:   VirtualAddress:
# CHECK-NEXT:   PhysicalAddress:
# CHECK-NEXT:   FileSize: 4096
# CHECK-NEXT:   MemSize:
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     PF_R
# CHECK-NEXT:     PF_X
# CHECK-NEXT:   ]

## Check that executable page is filled with traps at its end.
# LE: 010ff0 08 00 e0 7f 08 00 e0 7f 08 00 e0 7f 08 00 e0 7f
# BE: 010ff0 7f e0 00 08 7f e0 00 08 7f e0 00 08 7f e0 00 08

.globl _start
_start:
  nop
