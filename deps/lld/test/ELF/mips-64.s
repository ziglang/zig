# REQUIRES: mips
# Check R_MIPS_64 relocation calculation.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-objdump -t %t.so | FileCheck -check-prefix=SYM %s
# RUN: llvm-readobj -r --dynamic-table --mips-plt-got %t.so | FileCheck %s

  .global  __start
__start:
  nop

  .data
  .type  v1,@object
  .size  v1,4
v1:
  .quad 0

  .globl v2
  .type  v2,@object
  .size  v2,8
v2:
  .quad v2+8 # R_MIPS_64 target v2 addend 8
  .quad v1   # R_MIPS_64 target v1 addend 0


# SYM: SYMBOL TABLE:
# SYM: 00020000 l     O .data           00000004 v1
# SYM: 00020008 g     O .data           00000008 v2

# CHECK:      Relocations [
# CHECK-NEXT:   Section (7) .rel.dyn {
# CHECK-NEXT:     0x20010 R_MIPS_REL32/R_MIPS_64/R_MIPS_NONE - 0x0
# CHECK-NEXT:     0x20008 R_MIPS_REL32/R_MIPS_64/R_MIPS_NONE v2 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# CHECK: DynamicSection [
# CHECK:   Tag        Type     Name/Value
# CHECK:   0x0000000000000012 RELSZ    32 (bytes)
# CHECK:   0x0000000000000013 RELENT   16 (bytes)

# CHECK:      Primary GOT {
# CHECK-NEXT:   Canonical gp value:
# CHECK-NEXT:   Reserved entries [
# CHECK:        ]
# CHECK-NEXT:   Local entries [
# CHECK-NEXT:   ]
# CHECK-NEXT:   Global entries [
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address:
# CHECK-NEXT:       Access:
# CHECK-NEXT:       Initial: 0x20008
# CHECK-NEXT:       Value: 0x20008
# CHECK-NEXT:       Type: Object
# CHECK-NEXT:       Section: .data
# CHECK-NEXT:       Name: v2
# CHECK-NEXT:     }
# CHECK-NEXT:   ]
# CHECK-NEXT:   Number of TLS and multi-GOT entries: 0
# CHECK-NEXT: }
