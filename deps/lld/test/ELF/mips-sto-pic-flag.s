# REQUIRES: mips
# In case of linking PIC and non-PIC code together and generation
# of a relocatable object, all PIC symbols should have STO_MIPS_PIC
# flag in the symbol table of the ouput file.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t-npic.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:   %p/Inputs/mips-pic.s -o %t-pic.o
# RUN: ld.lld -r %t-npic.o %t-pic.o -o %t-rel.o
# RUN: llvm-readobj -t %t-rel.o | FileCheck %s

# CHECK:      Symbol {
# CHECK:        Name: main
# CHECK-NEXT:   Value:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Binding: Local
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: .text
# CHECK-NEXT: }
# CHECK:      Symbol {
# CHECK:        Name: foo1a
# CHECK-NEXT:   Value:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: Function
# CHECK-NEXT:   Other [
# CHECK-NEXT:     STO_MIPS_PIC
# CHECK-NEXT:   ]
# CHECK-NEXT:   Section: .text
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: foo1b
# CHECK-NEXT:   Value:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: Function
# CHECK-NEXT:   Other [
# CHECK-NEXT:     STO_MIPS_PIC
# CHECK-NEXT:   ]
# CHECK-NEXT:   Section: .text
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: foo2
# CHECK-NEXT:   Value:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: Function
# CHECK-NEXT:   Other [
# CHECK-NEXT:     STO_MIPS_PIC
# CHECK-NEXT:   ]
# CHECK-NEXT:   Section: .text
# CHECK-NEXT: }

  .text
main:
  nop
