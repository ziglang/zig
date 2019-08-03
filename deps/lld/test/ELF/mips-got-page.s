# REQUIRES: mips
# Check the case when small section (less that 0x10000 bytes) occupies
# two adjacent 0xffff-bytes pages. We need to create two GOT entries
# for R_MIPS_GOT_PAGE relocations.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux -o %t.o %s
# RUN: ld.lld --section-start .rodata=0x27FFC -shared -o %t.so %t.o
# RUN: llvm-readobj --symbols --mips-plt-got %t.so | FileCheck %s

# CHECK:       Name: bar
# CHECK-NEXT:  Value: 0x28000
#                     ^ page-address = (0x28000 + 0x8000) & ~0xffff = 0x30000

# CHECK:       Name: foo
# CHECK-NEXT:  Value: 0x27FFC
#                     ^ page-address = (0x27ffc + 0x8000) & ~0xffff = 0x20000

# CHECK:      Local entries [
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32736
# CHECK-NEXT:     Initial: 0x20000
# CHECK-NEXT:   }
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32728
# CHECK-NEXT:     Initial: 0x30000
# CHECK-NEXT:   }
# CHECK-NEXT: ]

  .text
  ld      $v0,%got_page(foo)($gp)
  ld      $v0,%got_page(bar)($gp)

  .rodata
foo:
  .word 0
bar:
  .word 0
