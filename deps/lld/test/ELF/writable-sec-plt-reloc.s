# REQUIRES: x86
# RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
# RUN: llvm-mc %p/Inputs/writable-sec-plt-reloc.s -o %t2.o -filetype=obj -triple=x86_64-pc-linux
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: ld.lld %t.o %t2.so -o %t
# RUN: llvm-readelf --symbols -r %t | FileCheck %s

# CHECK: R_X86_64_JUMP_SLOT {{.*}} foo + 0
# CHECK: 0000000000201010     0 FUNC    GLOBAL DEFAULT  UND foo

.section .bar,"awx"
.global _start
_start:
        .long foo - .
