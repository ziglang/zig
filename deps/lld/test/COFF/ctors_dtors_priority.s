# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-gnu -filetype=obj -o %t.obj %s
# RUN: lld-link -entry:main %t.obj -out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck %s

.globl main
main:
  nop

.section .ctors.00005, "w"
  .quad 2
.section .ctors, "w"
  .quad 1
.section .ctors.00100, "w"
  .quad 3

.section .dtors, "w"
  .quad 1
.section .dtors.00100, "w"
  .quad 3
.section .dtors.00005, "w"
  .quad 2

# CHECK:      Contents of section .ctors:
# CHECK-NEXT: 140002000 01000000 00000000 02000000 00000000
# CHECK-NEXT: 140002010 03000000 00000000

# CHECK:      Contents of section .dtors:
# CHECK-NEXT: 140003000 01000000 00000000 02000000 00000000
# CHECK-NEXT: 140003010 03000000 00000000
