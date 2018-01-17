# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/znotext-copy-relocations.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: ld.lld -z notext %t.o %t2.so -o %t
# RUN: llvm-readobj -r %t | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
# CHECK-NEXT:     R_X86_64_COPY foo 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.global _start
_start:
.long foo
