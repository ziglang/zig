# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .zed : { *(.foo) *(.bar) } }" > %t.script
# RUN: ld.lld --emit-relocs --script %t.script %t.o -o %t1
# RUN: llvm-readobj -r %t1 | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section {{.*}} .rela.zed {
# CHECK-NEXT:     0x1 R_X86_64_32 .zed 0x0
# CHECK-NEXT:     0x6 R_X86_64_32 .zed 0x5
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.section .foo,"ax",@progbits
aaa:
  movl $aaa, %edx

.section .bar,"ax",@progbits
bbb:
  movl $bbb, %edx
