# Check that R_MIPS_LO16 relocation is handled as non-relative,
# and if a target symbol is a DSO data symbol, LLD create a copy
# relocation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t.so.o
# RUN: ld.lld %t.so.o -shared -o %t.so
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o %t.so -o %t.exe
# RUN: llvm-readobj -r %t.exe | FileCheck %s

# REQUIRES: mips

# CHECK:      Relocations [
# CHECK-NEXT:   Section (7) .rel.dyn {
# CHECK-NEXT:     0x{{[0-9A-F]+}} R_MIPS_COPY data0 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

  .text
  .global __start
__start:
  addi   $t0, $t0, %lo(data0)
