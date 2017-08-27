// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t
// RUN: llvm-readobj -s -r -t %t | FileCheck %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s
// REQUIRES: x86

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x12000
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 0
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment:

// CHECK:      Symbol {
// CHECK:       Name: bar
// CHECK-NEXT:  Value: 0x12000
// CHECK-NEXT:  Size: 10
// CHECK-NEXT:  Binding: Global
// CHECK-NEXT:  Type: Object
// CHECK-NEXT:  Other: 0
// CHECK-NEXT:  Section: .bss
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:  Name: obj
// CHECK-NEXT:  Value: 0x1200A
// CHECK-NEXT:  Size: 10
// CHECK-NEXT:  Binding: Global
// CHECK-NEXT:  Type: Object
// CHECK-NEXT:  Other: 0
// CHECK-NEXT:  Section: .bss
// CHECK-NEXT: }

// 0x12000 - 0 = addr(.got) = 0x12000
// 0x1200A - 10 = addr(.got) = 0x12000
// 0x1200A + 5 - 15 = addr(.got) = 0x12000
// DISASM:      Disassembly of section .text:
// DISASM-NEXT: _start:
// DISASM-NEXT: 11000: c7 81 00 00 00 00 01 00 00 00 movl $1, (%ecx)
// DISASM-NEXT: 1100a: c7 81 0a 00 00 00 02 00 00 00 movl $2, 10(%ecx)
// DISASM-NEXT: 11014: c7 81 0f 00 00 00 03 00 00 00 movl $3, 15(%ecx)

.global _start
_start:
  movl $1, bar@GOTOFF(%ecx)
  movl $2, obj@GOTOFF(%ecx)
  movl $3, obj+5@GOTOFF(%ecx)
  .type bar, @object
  .comm bar, 10
  .type obj, @object
  .comm obj, 10
