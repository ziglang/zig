# REQUIRES: mips
# Check R_MIPS_GOT16 relocation against merge section.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux -o %t.o %s
# RUN: ld.lld -shared -o %t.so %t.o
# RUN: llvm-readobj -t -mips-plt-got %t.so | FileCheck %s

# CHECK:      Symbol {
# CHECK:        Name: $.str
# CHECK-NEXT:   Value: 0x1B1
# CHECK:      }

# CHECK:      Local entries [
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32744
# CHECK-NEXT:     Initial: 0x0
# CHECK:        }
# CHECK:      ]

  .text
  lw     $t9, %got($.str)($gp)
  addiu  $a0, $t9, %lo($.str)

  .section  .rodata.str,"aMS",@progbits,1
$.str:
  .asciz "foo"
