# REQUIRES: mips
# Check R_MIPS_GOT16 relocation against merge section.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux -o %t.o %s
# RUN: ld.lld -shared -o %t.so %t.o
# RUN: llvm-readelf --mips-plt-got %t.so | FileCheck %s

# CHECK:       Local entries:
# CHECK-NEXT:         Address     Access  Initial
# CHECK-NEXT:   {{[0-9a-f]+}} -32744(gp) 00000000
# CHECK-NEXT:   {{[0-9a-f]+}} -32740(gp) 00010000

  .text
  lw     $t9, %got($.str)($gp)
  addiu  $a0, $t9, %lo($.str)

  .section  .rodata.str,"aMS",@progbits,1
$.str:
  .asciz "foo"
