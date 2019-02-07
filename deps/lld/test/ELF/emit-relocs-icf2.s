# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --gc-sections --emit-relocs --icf=all %t.o -o %t
# RUN: llvm-readobj -r %t | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section (3) .rela.text {
# CHECK-NEXT:     0x201000 R_X86_64_64 .text 0x11
# CHECK-NEXT:     0x201008 R_X86_64_64 .text 0x11
# CHECK-NEXT:     0x201011 R_X86_64_64 .rodata 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.rodata
quux:
.quad 0xfe

.section .text.foo,"ax"
foo:
.quad quux

.section .text.bar,"ax"
bar:
.quad quux

.section .text.baz,"ax"
baz:
.quad quux

.text
.quad foo
.quad bar

.global _start
_start:
  nop
