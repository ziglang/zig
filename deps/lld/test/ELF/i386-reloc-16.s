# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386 %s -o %t.o

# RUN: ld.lld %t.o --defsym=a=0 --defsym=b=32768 -o %t
# RUN: llvm-readelf -x .text %t | FileCheck %s
# CHECK: b80080bb ffff

# RUN: not ld.lld %t.o --defsym=a=-1 --defsym=b=0 -o /dev/null 2>&1 | \
# RUN:   FileCheck --check-prefix=OVERFLOW1 %s
# OVERFLOW1: relocation R_386_16 out of range: -32769 is not in [-32768, 65535]

# RUN: not ld.lld %t.o --defsym=a=0 --defsym=b=32769 -o /dev/null 2>&1 | \
# RUN:   FileCheck --check-prefix=OVERFLOW2 %s
# OVERFLOW2: relocation R_386_16 out of range: 65536 is not in [-32768, 65535]

.code16
.global _start
_start:
movw $a-32768, %ax
movw $b+32767, %bx
