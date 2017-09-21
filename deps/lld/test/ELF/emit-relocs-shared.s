# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --emit-relocs %t.o -o %t.so -shared
# RUN: llvm-readobj -r %t.so | FileCheck %s

.data
.quad foo

# CHECK:      Relocations [
# CHECK-NEXT:   Section (4) .rela.dyn {
# CHECK-NEXT:     0x1000 R_X86_64_64 foo 0x0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section (8) .rela.data {
# CHECK-NEXT:     0x1000 R_X86_64_64 foo 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]
