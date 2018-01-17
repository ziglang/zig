# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -hash-style=gnu %t.o -o %t.so -shared
# RUN: llvm-readelf --gnu-hash-table %t.so | FileCheck %s

# CHECK: Num Buckets: 4

.global sym1
sym1:

.global sym2
sym2:

.global sym3
sym3:

.global sym4
sym4:

.global sym5
sym5:

.global sym6
sym6:

.global sym7
sym7:

.global sym8
sym8:

.global sym9
sym9:

.global sym10
sym10:

.global sym11
sym11:

.global sym12
sym12:

.global sym13
sym13:

.global sym14
sym14:

.global sym15
sym15:

.global sym16
sym16:
