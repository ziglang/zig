# REQUIRES: mips
# Check handling of relocations against __gnu_local_gp symbol.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld -o %t.exe %t.o
# RUN: llvm-objdump -d -t %t.exe | FileCheck %s

# CHECK:      Disassembly of section .text:
# CHECK-EMPTY:
# CHECK-NEXT: __start:
# CHECK-NEXT:    20000:  3c 08 00 03  lui   $8, 3
# CHECK-NEXT:    20004:  21 08 7f f0  addi  $8, $8, 32752

# CHECK: 00037ff0  .got  00000000 .hidden _gp

  .text
  .globl  __start
__start:
  lui    $t0,%hi(__gnu_local_gp)
  addi   $t0,$t0,%lo(__gnu_local_gp)
