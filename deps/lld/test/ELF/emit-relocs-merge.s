# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld --emit-relocs %t.o -o %t.so -shared
# RUN: llvm-readobj -r %t.so | FileCheck %s

# CHECK:       Relocations [
# CHECK-NEXT:    Section ({{.*}}) .rela.dyn {
# CHECK-NEXT:     0x2000 R_X86_64_64 zed 0x0
# CHECK-NEXT:     0x2008 R_X86_64_64 zed 0x0
# CHECK-NEXT:   }
# CHECK-NEXT:   Section ({{.*}}) .rela.data {
# CHECK-NEXT:     0x2000 R_X86_64_64 zed 0x0
# CHECK-NEXT:     0x2008 R_X86_64_64 zed 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.section        .data.foo,"aw",%progbits
.quad zed
.section        .data.bar,"aw",%progbits
.quad zed
