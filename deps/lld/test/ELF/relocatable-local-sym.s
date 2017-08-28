# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: ld.lld -r %t1.o -o %t2.o
# RUN: llvm-readobj -r %t2.o | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.text {
# CHECK-NEXT:     0x3 R_X86_64_PC32 .Lstr 0xFFFFFFFFFFFFFFFC
# CHECK-NEXT:   }
# CHECK-NEXT: ]

        leaq    .Lstr(%rip), %rdi

        .section        .rodata.str1.1,"aMS",@progbits,1
        .Lstr:
        .asciz "abc\n"
