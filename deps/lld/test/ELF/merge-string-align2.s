# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o

# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -S %t | FileCheck --check-prefix=SEC %s
# RUN: llvm-readelf -x .rodata %t | FileCheck %s

# SEC: Name    Type     {{.*}} Size   ES Flg Lk Inf Al
# SEC: .rodata PROGBITS {{.*}} 000006 01 AMS  0   0  8

## Check there is no extra padding.

# CHECK: a.b.c.

.section .rodata.str1.8,"aMS",@progbits,1
.align 8
.asciz "a"

.section .rodata.str1.2,"aMS",@progbits,1
.align 2
.asciz "b"

.section .rodata.str1.1,"aMS",@progbits,1
.align 1
.asciz "c"
