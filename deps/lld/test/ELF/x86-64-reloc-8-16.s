# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64 %S/Inputs/abs255.s -o %t255.o
# RUN: llvm-mc -filetype=obj -triple=x86_64 %S/Inputs/abs256.s -o %t256.o
# RUN: llvm-mc -filetype=obj -triple=x86_64 %S/Inputs/abs257.s -o %t257.o

# RUN: ld.lld %t.o %t256.o -o %t
# RUN: llvm-readelf -x .data %t | FileCheck %s
# CHECK: 0x{{[0-9a-f]+}} ff80ffff 0080

# RUN: not ld.lld %t.o %t255.o -o /dev/null 2>&1 | FileCheck --check-prefix=OVERFLOW1 %s
# OVERFLOW1: relocation R_X86_64_8 out of range: -129 is not in [-128, 255]
# OVERFLOW1: relocation R_X86_64_16 out of range: -32769 is not in [-32768, 65535]

# RUN: not ld.lld %t.o %t257.o -o /dev/null 2>&1 | FileCheck --check-prefix=OVERFLOW2 %s
# OVERFLOW2: relocation R_X86_64_8 out of range: 256 is not in [-128, 255]
# OVERFLOW2: relocation R_X86_64_16 out of range: 65536 is not in [-32768, 65535]

.globl _start
_start:
.data
.byte foo - 1
.byte foo - 384
.word foo + 0xfeff
.word foo - 0x8100
