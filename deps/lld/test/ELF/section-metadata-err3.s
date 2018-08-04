# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s

# CHECK:      error: incompatible section flags for .bar
# CHECK-NEXT: >>> {{.*}}section-metadata-err3.s.tmp.o:(.bar): 0x2
# CHECK-NEXT: >>> output section .bar: 0x82

.section .foo,"a",@progbits
.quad 0

.section .bar,"ao",@progbits,.foo,unique,1
.quad 0

.section .bar,"a",@progbits,unique,2
.quad 1
