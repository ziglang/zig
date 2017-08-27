# Check R_MIPS_HIGHER / R_MIPS_HIGHEST relocations calculation.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t2.o
# RUN: ld.lld %t1.o %t2.o -o %t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck %s

# REQUIRES: mips

  .global  __start
__start:
  lui     $6, %highest(_foo+0x300047FFF7FF7)
  daddiu  $6, $6, %higher(_foo+0x300047FFF7FF7)
  lui     $7, %highest(_foo+0x300047FFF7FF8)
  ld      $7, %higher (_foo+0x300047FFF7FF8)($7)

# CHECK:      20000:       3c 06 00 03     lui     $6, 3
# CHECK-NEXT: 20004:       64 c6 00 05     daddiu  $6, $6, 5
# CHECK-NEXT: 20008:       3c 07 00 03     lui     $7, 3
# CHECK-NEXT: 2000c:       dc e7 00 05     ld      $7, 5($7)
