# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t1 --gc-sections
# RUN: llvm-objdump -s %t1 | FileCheck %s

# CHECK:      Contents of section .debug_str:
# CHECK-NEXT:  0000 41414100 43434300 42424200           AAA.CCC.BBB.
# CHECK:      Contents of section .foo:
# CHECK-NEXT:  0000 2a000000
# CHECK:      Contents of section .debug_info:
# CHECK-NEXT:  0000 00000000 08000000

.globl _start
_start:

.section .debug_str,"MS",@progbits,1
.Linfo_string0:
  .asciz "AAA"
.Linfo_string1:
  .asciz "BBB"
.Linfo_string2:
  .asciz "CCC"

.section .foo,"M",@progbits,4
.p2align 2
  .long 42

.section  .debug_info,"",@progbits
  .long .Linfo_string0
  .long .Linfo_string1
