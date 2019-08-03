# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc64le %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le %S/Inputs/abs255.s -o %t255.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le %S/Inputs/abs256.s -o %t256.o
# RUN: llvm-mc -filetype=obj -triple=powerpc64le %S/Inputs/abs257.s -o %t257.o

# RUN: ld.lld %t.o %t256.o -o %t
# RUN: llvm-readelf -x .data %t | FileCheck %s
# CHECK: 0x{{[0-9a-f]+}} ffff0080 ffffffff 00000080

# RUN: not ld.lld %t.o %t255.o -o /dev/null 2>&1 | FileCheck --check-prefix=OVERFLOW1 %s
# OVERFLOW1: relocation R_PPC64_ADDR16 out of range: -32769 is not in [-32768, 65535]
# OVERFLOW1: relocation R_PPC64_ADDR32 out of range: -2147483649 is not in [-2147483648, 4294967295]

# RUN: not ld.lld %t.o %t257.o -o /dev/null 2>&1 | FileCheck --check-prefix=OVERFLOW2 %s
# OVERFLOW2: relocation R_PPC64_ADDR16 out of range: 65536 is not in [-32768, 65535]
# OVERFLOW2: relocation R_PPC64_ADDR32 out of range: 4294967296 is not in [-2147483648, 4294967295]

.globl _start
_start:
.data
.word foo + 0xfeff
.word foo - 0x8100
.long foo + 0xfffffeff
.long foo - 0x80000100
