# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-readobj -program-headers %t2 | FileCheck %s

# CHECK:      Type: PT_GNU_RELRO
# CHECK-NEXT: Offset:
# CHECK-NEXT: VirtualAddress:
# CHECK-NEXT: PhysicalAddress:
# CHECK-NEXT: FileSize:
# CHECK-NEXT: MemSize: 4096

.section .data.rel.ro,"aw",%progbits
.byte 1
