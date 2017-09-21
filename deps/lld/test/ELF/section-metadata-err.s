# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld %t.o -o %t 2>&1 | FileCheck %s

# CHECK: error: Merge and .eh_frame sections are not supported with SHF_LINK_ORDER {{.*}}section-metadata-err.s.tmp.o:(.foo)

.global _start
_start:
.quad .foo

.section .foo,"aM",@progbits,8
.quad 0

.section bar,"ao",@progbits,.foo
