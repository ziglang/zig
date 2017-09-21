# Check creation of GOT entries for global symbols in case of executable
# file linking. Symbols defined in DSO should get entries in the global part
# of the GOT. Symbols defined in the executable itself should get local GOT
# entries and does not need a row in .dynsym table.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t.so.o
# RUN: ld.lld -shared %t.so.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o %t.so -o %t.exe
# RUN: llvm-readobj -dt -t -mips-plt-got %t.exe | FileCheck %s

# REQUIRES: mips

# CHECK:      Symbols [
# CHECK:        Symbol {
# CHECK:          Name: _foo
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global

# CHECK:        Symbol {
# CHECK:          Name: bar
# CHECK-NEXT:     Value: 0x20008
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding: Global

# CHECK:     DynamicSymbols [
# CHECK-NOT:      Name: bar

# CHECK:      Local entries [
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32744
# CHECK-NEXT:     Initial: 0x20008
#                          ^-- bar
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK-NEXT: Global entries [
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32740
# CHECK-NEXT:     Initial: 0x0
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Type: None
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:     Name: _foo@
# CHECK-NEXT:   }
# CHECK-NEXT: ]

  .text
  .globl  __start
__start:
  lw      $t0,%got(bar)($gp)
  lw      $t0,%got(_foo)($gp)

.global bar
bar:
  .word 0
