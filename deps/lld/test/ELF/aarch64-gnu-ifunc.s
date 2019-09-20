// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %s -o %t.o
// RUN: ld.lld -static %t.o -o %tout
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-readobj -r --symbols --sections %tout | FileCheck %s

// CHECK:      Sections [
// CHECK:       Section {
// CHECK:       Index: 1
// CHECK-NEXT:  Name: .rela.plt
// CHECK-NEXT:  Type: SHT_RELA
// CHECK-NEXT:  Flags [
// CHECK-NEXT:    SHF_ALLOC
// CHECK-NEXT:  ]
// CHECK-NEXT:  Address: [[RELA:.*]]
// CHECK-NEXT:  Offset: 0x158
// CHECK-NEXT:  Size: 48
// CHECK-NEXT:  Link: 0
// CHECK-NEXT:  Info: 4
// CHECK-NEXT:  AddressAlignment: 8
// CHECK-NEXT:  EntrySize: 24
// CHECK-NEXT: }
// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.plt {
// CHECK-NEXT:     0x220000 R_AARCH64_IRELATIVE
// CHECK-NEXT:     0x220008 R_AARCH64_IRELATIVE
// CHECK-NEXT:   }
// CHECK-NEXT: ]
// CHECK:      Symbols [
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name:
// CHECK-NEXT:    Value: 0x0
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Local
// CHECK-NEXT:    Type: None
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: Undefined
// CHECK-NEXT:  }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: $x.0
// CHECK-NEXT:    Value: 0x210000
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Local
// CHECK-NEXT:    Type: None
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .text
// CHECK-NEXT:  }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: __rela_iplt_end
// CHECK-NEXT:    Value: 0x200188
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Local
// CHECK-NEXT:    Type: None
// CHECK-NEXT:    Other [
// CHECK-NEXT:      STV_HIDDEN
// CHECK-NEXT:    ]
// CHECK-NEXT:    Section: .rela.plt
// CHECK-NEXT:  }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: __rela_iplt_start
// CHECK-NEXT:    Value: 0x200158
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Local
// CHECK-NEXT:    Type: None
// CHECK-NEXT:    Other [
// CHECK-NEXT:      STV_HIDDEN
// CHECK-NEXT:    ]
// CHECK-NEXT:    Section: .rela.plt
// CHECK-NEXT:  }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: _start
// CHECK-NEXT:    Value: 0x210008
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Global
// CHECK-NEXT:    Type: None
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .text
// CHECK-NEXT:  }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: bar
// CHECK-NEXT:    Value: 0x210004
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Global
// CHECK-NEXT:    Type: GNU_IFunc
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .text
// CHECK-NEXT:  }
// CHECK-NEXT:  Symbol {
// CHECK-NEXT:    Name: foo
// CHECK-NEXT:    Value: 0x210000
// CHECK-NEXT:    Size: 0
// CHECK-NEXT:    Binding: Global
// CHECK-NEXT:    Type: GNU_IFunc
// CHECK-NEXT:    Other: 0
// CHECK-NEXT:    Section: .text
// CHECK-NEXT:  }
// CHECK-NEXT: ]

// 344 = 0x158
// 392 = 0x188

// DISASM: Disassembly of section .text:
// DISASM-EMPTY:
// DISASM-NEXT: foo:
// DISASM-NEXT:  210000: c0 03 5f d6 ret
// DISASM: bar:
// DISASM-NEXT:  210004: c0 03 5f d6 ret
// DISASM:      _start:
// DISASM-NEXT:  210008: 06 00 00 94 bl #24
// DISASM-NEXT:  21000c: 09 00 00 94     bl      #36
// DISASM-NEXT:  210010: 42 60 05 91     add     x2, x2, #344
// DISASM-NEXT:  210014: 42 20 06 91     add     x2, x2, #392
// DISASM-EMPTY:
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-EMPTY:
// DISASM-NEXT: .plt:
// DISASM-NEXT:  210020: 90 00 00 90 adrp x16, #65536
// DISASM-NEXT:  210024: 11 02 40 f9 ldr x17, [x16]
// DISASM-NEXT:  210028: 10 02 00 91 add x16, x16, #0
// DISASM-NEXT:  21002c: 20 02 1f d6 br x17
// DISASM-NEXT:  210030: 90 00 00 90 adrp x16, #65536
// DISASM-NEXT:  210034: 11 06 40 f9 ldr x17, [x16, #8]
// DISASM-NEXT:  210038: 10 22 00 91 add x16, x16, #8
// DISASM-NEXT:  21003c: 20 02 1f d6 br x17

.text
.type foo STT_GNU_IFUNC
.globl foo
foo:
 ret

.type bar STT_GNU_IFUNC
.globl bar
bar:
 ret

.globl _start
_start:
 bl foo
 bl bar
 add x2, x2, :lo12:__rela_iplt_start
 add x2, x2, :lo12:__rela_iplt_end
