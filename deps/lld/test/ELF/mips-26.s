# REQUIRES: mips
# Check R_MIPS_26 relocation handling.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t2.o
# RUN: ld.lld %t2.o -shared -o %t.so
# RUN: ld.lld %t1.o %t.so -o %t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck %s
# RUN: llvm-readobj --dynamic-table -S -r --mips-plt-got %t.exe \
# RUN:   | FileCheck -check-prefix=REL %s

# CHECK:      Disassembly of section .text:
# CHECK-EMPTY:
# CHECK-NEXT: bar:
# CHECK-NEXT:   20000:       0c 00 80 06     jal     131096 <loc>
# CHECK-NEXT:   20004:       00 00 00 00     nop
#
# CHECK:      __start:
# CHECK-NEXT:   20008:       0c 00 80 00     jal     131072 <bar>
# CHECK-NEXT:   2000c:       00 00 00 00     nop
# CHECK-NEXT:   20010:       0c 00 80 10     jal     131136
#                                                    ^-- 0x20040 gotplt[foo0]
# CHECK-NEXT:   20014:       00 00 00 00     nop
#
# CHECK:      loc:
# CHECK-NEXT:   20018:       00 00 00 00     nop
# CHECK-EMPTY:
# CHECK-NEXT: Disassembly of section .plt:
# CHECK-EMPTY:
# CHECK-NEXT: .plt:
# CHECK-NEXT:   20020:       3c 1c 00 03     lui     $gp, 3
# CHECK-NEXT:   20024:       8f 99 00 04     lw      $25, 4($gp)
# CHECK-NEXT:   20028:       27 9c 00 04     addiu   $gp, $gp, 4
# CHECK-NEXT:   2002c:       03 1c c0 23     subu    $24, $24, $gp
# CHECK-NEXT:   20030:       03 e0 78 25     move    $15, $ra
# CHECK-NEXT:   20034:       00 18 c0 82     srl     $24, $24, 2
# CHECK-NEXT:   20038:       03 20 f8 09     jalr    $25
# CHECK-NEXT:   2003c:       27 18 ff fe     addiu   $24, $24, -2
# CHECK-NEXT:   20040:       3c 0f 00 03     lui     $15, 3
# CHECK-NEXT:   20044:       8d f9 00 0c     lw      $25, 12($15)
# CHECK-NEXT:   20048:       03 20 00 08     jr      $25
# CHECK-NEXT:   2004c:       25 f8 00 0c     addiu   $24, $15, 12

# REL:      Name: .plt
# REL-NEXT: Type: SHT_PROGBITS
# REL-NEXT: Flags [ (0x6)
# REL-NEXT:   SHF_ALLOC
# REL-NEXT:   SHF_EXECINSTR
# REL-NEXT: ]
# REL-NEXT: Address: 0x[[PLTADDR:[0-9A-F]+]]

# REL:      Name: .got.plt
# REL-NEXT: Type: SHT_PROGBITS
# REL-NEXT: Flags [ (0x3)
# REL-NEXT:   SHF_ALLOC
# REL-NEXT:   SHF_WRITE
# REL-NEXT: ]
# REL-NEXT: Address: 0x[[GOTPLTADDR:[0-9A-F]+]]

# REL: Relocations [
# REL-NEXT:   Section (7) .rel.plt {
# REL-NEXT:     0x[[PLTSLOT:[0-9A-F]+]] R_MIPS_JUMP_SLOT foo0 0x0
# REL-NEXT:   }
# REL-NEXT: ]

# REL: 0x70000032  MIPS_PLTGOT  0x[[GOTPLTADDR]]

# REL:      Primary GOT {
# REL:        Local entries [
# REL-NEXT:   ]
# REL-NEXT:   Global entries [
# REL-NEXT:   ]
# REL:      PLT GOT {
# REL:        Entries [
# REL-NEXT:     Entry {
# REL-NEXT:       Address: 0x[[PLTSLOT]]
# REL-NEXT:       Initial: 0x[[PLTADDR]]
# REL-NEXT:       Value: 0x0
# REL-NEXT:       Type: Function
# REL-NEXT:       Section: Undefined
# REL-NEXT:       Name: foo0
# REL-NEXT:     }
# REL-NEXT:   ]

  .text
  .globl bar
bar:
  jal loc         # R_MIPS_26 against .text + offset

  .globl __start
__start:
  jal bar         # R_MIPS_26 against global 'bar' from object file
  jal foo0        # R_MIPS_26 against 'foo0' from DSO

loc:
  nop
