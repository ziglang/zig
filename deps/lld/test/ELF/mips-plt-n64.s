# REQUIRES: mips
# Check R_MIPS_26 relocation handling in case of N64 ABIs.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t-so.o
# RUN: ld.lld %t-so.o -shared -o %t.so
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o %t.so -o %t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck %s --check-prefixes=CHECK,DEFAULT
# RUN: ld.lld %t-so.o -shared -o %t.so -z hazardplt
# RUN: ld.lld %t.o %t.so -o %t.exe -z hazardplt
# RUN: llvm-objdump -d %t.exe | FileCheck %s --check-prefixes=CHECK,HAZARDPLT

# CHECK:      Disassembly of section .text:
# CHECK-EMPTY:
# CHECK-NEXT: __start:
# CHECK-NEXT:    20000:       0c 00 80 0c     jal     131120
# CHECK-NEXT:    20004:       00 00 00 00     nop
# CHECK-EMPTY:
# CHECK-NEXT: Disassembly of section .plt:
# CHECK-EMPTY:
# CHECK-NEXT: .plt:
# CHECK-NEXT:    20010:       3c 0e 00 03     lui     $14, 3
# CHECK-NEXT:    20014:       dd d9 00 08     ld      $25, 8($14)
# CHECK-NEXT:    20018:       25 ce 00 08     addiu   $14, $14, 8
# CHECK-NEXT:    2001c:       03 0e c0 23     subu    $24, $24, $14
# CHECK-NEXT:    20020:       03 e0 78 25     move    $15, $ra
# CHECK-NEXT:    20024:       00 18 c0 c2     srl     $24, $24, 3
# DEFAULT:       20028:       03 20 f8 09     jalr    $25
# HAZARDPLT:     20028:       03 20 fc 09     jalr.hb $25
# CHECK-NEXT:    2002c:       27 18 ff fe     addiu   $24, $24, -2
# CHECK-NEXT:    20030:       3c 0f 00 03     lui     $15, 3
# CHECK-NEXT:    20034:       dd f9 00 18     ld      $25, 24($15)
# DEFAULT:       20038:       03 20 00 08     jr      $25
# HAZARDPLT:     20038:       03 20 04 08     jr.hb   $25
# CHECK-NEXT:    2003c:       65 f8 00 18     daddiu  $24, $15, 24

  .text
  .option pic0
  .global __start
__start:
  jal   foo0
