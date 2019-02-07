# REQUIRES: mips
# Check less-significant bit setup for microMIPS PLT.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %S/Inputs/mips-dynamic.s -o %t-dso.o
# RUN: ld.lld %t-dso.o -shared -o %t.so
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mattr=micromips %s -o %t-exe.o
# RUN: ld.lld %t-exe.o %t.so -o %t.exe
# RUN: llvm-readobj -t -dt -mips-plt-got %t.exe | FileCheck %s
# RUN: llvm-objdump -d -mattr=micromips %t.exe | FileCheck --check-prefix=ASM %s

# CHECK:      Symbols [
# CHECK:        Symbol {
# CHECK:          Name: foo
# CHECK-NEXT:     Value: 0x20010
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other [
# CHECK-NEXT:       STO_MIPS_MICROMIPS
# CHECK-NEXT:       STV_HIDDEN
# CHECK-NEXT:     ]
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK:        Symbol {
# CHECK:          Name: __start
# CHECK-NEXT:     Value: 0x20000
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Other [
# CHECK-NEXT:       STO_MIPS_MICROMIPS
# CHECK-NEXT:     ]
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK:        Symbol {
# CHECK:          Name: foo0
# CHECK-NEXT:     Value: 0x20040
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: Function
# CHECK-NEXT:     Other [
# CHECK-NEXT:       STO_MIPS_MICROMIPS
# CHECK-NEXT:       STO_MIPS_PLT
# CHECK-NEXT:     ]
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK:      DynamicSymbols [
# CHECK:        Symbol {
# CHECK:          Name: foo0
# CHECK-NEXT:     Value: 0x20041
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type: Function
# CHECK-NEXT:     Other [
# CHECK-NEXT:       STO_MIPS_MICROMIPS
# CHECK-NEXT:       STO_MIPS_PLT
# CHECK-NEXT:     ]
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# CHECK:      Primary GOT {
# CHECK:        Local entries [
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address:
# CHECK-NEXT:       Access:
# CHECK-NEXT:       Initial: 0x20011
# CHECK-NEXT:     }
# CHECK:        ]
# CHECK:      }

# CHECK:      PLT GOT {
# CHECK:        Entries [
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address:
# CHECK-NEXT:       Initial: 0x20021
# CHECK-NEXT:       Value: 0x20041
# CHECK-NEXT:       Type: Function
# CHECK-NEXT:       Section: Undefined
# CHECK-NEXT:       Name: foo0
# CHECK-NEXT:     }
# CHECK-NEXT:   ]
# CHECK-NEXT: }

# ASM:      __start:
# ASM-NEXT:    20000:       fd 1c 80 18     lw      $8, -32744($gp)
# ASM-NEXT:    20004:       11 08 00 10     addi    $8, $8, 16
# ASM-NEXT:    20008:       41 a8 00 02     lui     $8, 2
# ASM-NEXT:    2000c:       11 08 00 40     addi    $8, $8, 64
#
# ASM:      foo:
# ASM-NEXT:    20010:       f4 01 00 20     jal     131136

  .text
  .set micromips
  .global foo
  .hidden foo
  .global __start
__start:
  lw    $t0,%got(foo)($gp)
  addi  $t0,$t0,%lo(foo)
  lui   $t0,%hi(foo0)
  addi  $t0,$t0,%lo(foo0)
foo:
  jal   foo0
