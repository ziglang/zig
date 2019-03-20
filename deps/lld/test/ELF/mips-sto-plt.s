# REQUIRES: mips
# Check assigning STO_MIPS_PLT flag to symbol needs a pointer equality.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t.so.o
# RUN: ld.lld %t.so.o -shared -o %t.so
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o %t.so -o %t.exe
# RUN: llvm-readobj -dt -mips-plt-got %t.exe | FileCheck %s

# CHECK:      Symbol {
# CHECK:        Name: foo0
# CHECK-NEXT:   Value: 0x0
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: Function
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: Undefined
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: foo1
# CHECK-NEXT:   Value: 0x[[FOO1:[0-9A-F]+]]
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: Function
# CHECK-NEXT:   Other [ (0x8)
# CHECK-NEXT:     STO_MIPS_PLT
# CHECK-NEXT:   ]
# CHECK-NEXT:   Section: Undefined
# CHECK-NEXT: }

# CHECK:      Primary GOT {
# CHECK:        Local entries [
# CHECK-NEXT:   ]
# CHECK-NEXT:   Global entries [
# CHECK-NEXT:   ]
# CHECK:      PLT GOT {
# CHECK:        Entries [
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address:
# CHECK-NEXT:       Initial:
# CHECK-NEXT:       Value: 0x0
# CHECK-NEXT:       Type: Function
# CHECK-NEXT:       Section: Undefined
# CHECK-NEXT:       Name: foo0
# CHECK-NEXT:     }
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address:
# CHECK-NEXT:       Initial:
# CHECK-NEXT:       Value: 0x[[FOO1]]
# CHECK-NEXT:       Type: Function
# CHECK-NEXT:       Section: Undefined
# CHECK-NEXT:       Name: foo1
# CHECK-NEXT:     }
# CHECK-NEXT:   ]

  .text
  .globl __start
__start:
  jal    foo0               # R_MIPS_26 against 'foo0' from DSO
  lui    $t0,%hi(foo1)      # R_MIPS_HI16/LO16 against 'foo1' from DSO
  addi   $t0,$t0,%lo(foo1)

loc:
  nop
