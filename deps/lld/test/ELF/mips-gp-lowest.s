# REQUIRES: mips
# Check that default _gp value is calculated relative
# to the GP-relative section with the lowest address.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:          .sdata : { *(.sdata) } \
# RUN:          .got  : { *(.got) } }" > %t.rel.script
# RUN: ld.lld %t.o --script %t.rel.script -shared -o %t.so
# RUN: llvm-readobj -S --symbols %t.so | FileCheck %s

  .text
  .global foo
foo:
  lui  $gp, %call16(foo)

  .sdata
  .word 0

# CHECK:      Section {
# CHECK:        Name: .sdata
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_MIPS_GPREL
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0xF0
# CHECK:      }
# CHECK:      Section {
# CHECK:        Name: .got
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_MIPS_GPREL
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x100
# CHECK:      }

# CHECK:      Name: _gp (5)
# CHECK-NEXT: Value: 0x80E0
#                    ^-- 0xF0 + 0x7ff0
