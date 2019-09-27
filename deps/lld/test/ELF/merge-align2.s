# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o

# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -S %t | FileCheck --check-prefix=SEC %s
# RUN: llvm-readelf -x .cst8 %t | FileCheck %s

# RUN: ld.lld -O0 -r %t.o -o %t1.o
# RUN: llvm-readelf -S %t1.o | FileCheck --check-prefix=SEC %s
# RUN: llvm-readelf -x .cst8 %t1.o | FileCheck %s

## Check that if we have SHF_MERGE sections with the same name, flags and
## entsize, but different alignments, we combine them with the maximum input
## alignment as the output alignment.

# SEC: Name  Type     {{.*}} Size   ES Flg Lk Inf Al
# SEC: .cst8 PROGBITS {{.*}} 000018 08  AM  0   0  8

# CHECK:      0x{{[0-9a-f]+}} 02000000 00000000 01000000 00000000
# CHECK-NEXT: 0x{{[0-9a-f]+}} 03000000 00000000

.section .cst8,"aM",@progbits,8,unique,0
.align 4
.quad 1
.quad 1

.section .cst8,"aM",@progbits,8,unique,1
.align 4
.quad 1
.quad 2

.section .cst8,"aM",@progbits,8,unique,2
.align 8
.quad 1
.quad 3
