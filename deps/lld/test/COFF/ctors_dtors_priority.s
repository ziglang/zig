# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-gnu -filetype=obj -o %t.obj %s
# RUN: lld-link -lldmingw -entry:main %t.obj -out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck %s

.globl main
main:
  nop

# Check that these symbols point at the right spots.
.data
  .quad __CTOR_LIST__
  .quad __DTOR_LIST__

.section .ctors.00005, "w"
  .quad 2
.section .ctors, "w"
  .quad 1
.section .ctors.00100, "w"
  .quad 3

.section .dtors, "w"
  .quad 4
.section .dtors.00100, "w"
  .quad 6
.section .dtors.00005, "w"
  .quad 5

# Also test that the .CRT section is merged into .rdata

.section .CRT$XCA, "dw"
  .quad 7
  .quad 8

# CHECK:      Contents of section .rdata:
# CHECK-NEXT: 140002000 07000000 00000000 08000000 00000000
# CHECK-NEXT: 140002010 ffffffff ffffffff 01000000 00000000
# CHECK-NEXT: 140002020 02000000 00000000 03000000 00000000
# CHECK-NEXT: 140002030 00000000 00000000 ffffffff ffffffff
# CHECK-NEXT: 140002040 04000000 00000000 05000000 00000000
# CHECK-NEXT: 140002050 06000000 00000000 00000000 00000000
# __CTOR_LIST__ pointing at 0x140002010 and
# __DTOR_LIST__ pointing at 0x140002038.
# CHECK-NEXT: Contents of section .data:
# CHECK-NEXT: 140003000 10200040 01000000 38200040 01000000
