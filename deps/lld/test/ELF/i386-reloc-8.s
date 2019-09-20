# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386 %s -o %t.o

# RUN: ld.lld %t.o --defsym=a=0 --defsym=b=128 -o %t
# RUN: llvm-readelf -x .text %t | FileCheck %s
# CHECK: b480b7ff

# RUN: not ld.lld %t.o --defsym=a=-1 --defsym=b=0 -o /dev/null 2>&1 | \
# RUN:   FileCheck --check-prefix=OVERFLOW1 %s
# OVERFLOW1: relocation R_386_8 out of range: -129 is not in [-128, 255]

# RUN: not ld.lld %t.o --defsym=a=0 --defsym=b=129 -o /dev/null 2>&1 | \
# RUN:   FileCheck --check-prefix=OVERFLOW2 %s
# OVERFLOW2: relocation R_386_8 out of range: 256 is not in [-128, 255]

.code16
.globl _start
_start:
movb $a-128, %ah
movb $b+127, %bh
