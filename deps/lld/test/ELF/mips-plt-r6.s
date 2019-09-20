# REQUIRES: mips
# Check PLT entries generation in case of R6 ABI version.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mcpu=mips32r6 %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mcpu=mips32r6 %S/Inputs/mips-dynamic.s -o %t2.o
# RUN: ld.lld %t2.o -shared -o %t.so
# RUN: ld.lld %t1.o %t.so -o %t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck %s --check-prefixes=DEFAULT,CHECK
# RUN: ld.lld %t2.o -shared -o %t.so -z hazardplt
# RUN: ld.lld %t1.o %t.so -o %t.exe -z hazardplt
# RUN: llvm-objdump -d %t.exe | FileCheck %s --check-prefixes=HAZARDPLT,CHECK

# CHECK:      Disassembly of section .text:
# CHECK-EMPTY:
# CHECK-NEXT: __start:
# CHECK-NEXT:   20000:       0c 00 80 0c     jal     131120
#                                                    ^-- 0x20030 gotplt[foo0]
# CHECK-NEXT:   20004:       00 00 00 00     nop
#
# CHECK-EMPTY:
# CHECK-NEXT: Disassembly of section .plt:
# CHECK-EMPTY:
# CHECK-NEXT: .plt:
# CHECK-NEXT:   20010:       3c 1c 00 03     aui     $gp, $zero, 3
# CHECK-NEXT:   20014:       8f 99 00 04     lw      $25, 4($gp)
# CHECK-NEXT:   20018:       27 9c 00 04     addiu   $gp, $gp, 4
# CHECK-NEXT:   2001c:       03 1c c0 23     subu    $24, $24, $gp
# CHECK-NEXT:   20020:       03 e0 78 25     move    $15, $ra
# CHECK-NEXT:   20024:       00 18 c0 82     srl     $24, $24, 2
# DEFAULT:      20028:       03 20 f8 09     jalr    $25
# HAZARDPLT:    20028:       03 20 fc 09     jalr.hb $25
# CHECK-NEXT:   2002c:       27 18 ff fe     addiu   $24, $24, -2

# CHECK-NEXT:   20030:       3c 0f 00 03     aui     $15, $zero, 3
# CHECK-NEXT:   20034:       8d f9 00 0c     lw      $25, 12($15)
# DEFAULT:      20038:       03 20 00 09     jr      $25
# HAZARDPLT:    20038:       03 20 04 09     jr.hb   $25
# CHECK-NEXT:   2003c:       25 f8 00 0c     addiu   $24, $15, 12

  .text
  .global __start
__start:
  jal foo0        # R_MIPS_26 against 'foo0' from DSO
