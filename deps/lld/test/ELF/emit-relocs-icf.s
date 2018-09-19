# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld --emit-relocs --icf=all %t1.o -o %t
# RUN: llvm-readobj -r %t | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section {{.*}} .rela.text {
# CHECK-NEXT:     R_X86_64_32 .text 0x1
# CHECK-NEXT:     R_X86_64_PLT32 fn 0xFFFFFFFFFFFFFFFC
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.section .text.fn,"ax",@progbits,unique,0
.globl fn
.type fn,@function
fn:
 nop

bar:
  movl $bar, %edx
  callq fn@PLT
  nop

.section .text.fn2,"ax",@progbits,unique,1
.globl fn2
.type fn2,@function
fn2:
 nop

foo:
  movl $foo, %edx
  callq fn2@PLT
  nop
