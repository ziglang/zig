// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: ld.lld -static %t.o -o %tout
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-readobj -r -symbols -sections %tout | FileCheck %s

// CHECK:      Sections [
// CHECK:       Section {
// CHECK:       Index: 1
// CHECK-NEXT:  Name: .rel.plt
// CHECK-NEXT:  Type: SHT_REL
// CHECK-NEXT:  Flags [
// CHECK-NEXT:    SHF_ALLOC
// CHECK-NEXT:  ]
// CHECK-NEXT:  Address: [[RELA:.*]]
// CHECK-NEXT:  Offset: 0xD4
// CHECK-NEXT:  Size: 16
// CHECK-NEXT:  Link: 0
// CHECK-NEXT:  Info: 0
// CHECK-NEXT:  AddressAlignment: 4
// CHECK-NEXT:  EntrySize: 8
// CHECK-NEXT: }
// CHECK:     Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rel.plt {
// CHECK-NEXT:     0x12000 R_386_IRELATIVE
// CHECK-NEXT:     0x12004 R_386_IRELATIVE
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// CHECK:      Symbols [
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name:
// CHECK-NEXT:   Value: 0x0
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Local
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other: 0
// CHECK-NEXT:   Section: Undefined
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: __rel_iplt_end
// CHECK-NEXT:   Value: 0x100E4
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Local
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other [
// CHECK-NEXT:     STV_HIDDEN
// CHECK-NEXT:   ]
// CHECK-NEXT:   Section: .rel.plt
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: __rel_iplt_start
// CHECK-NEXT:   Value: [[RELA]]
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Local
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other [
// CHECK-NEXT:     STV_HIDDEN
// CHECK-NEXT:   ]
// CHECK-NEXT:   Section: .rel.plt
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: _start
// CHECK-NEXT:   Value: 0x11002
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Global
// CHECK-NEXT:   Type: None
// CHECK-NEXT:   Other: 0
// CHECK-NEXT:   Section: .text
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: bar
// CHECK-NEXT:   Value: 0x11001
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Global
// CHECK-NEXT:   Type: GNU_IFunc
// CHECK-NEXT:   Other: 0
// CHECK-NEXT:   Section: .text
// CHECK-NEXT: }
// CHECK-NEXT: Symbol {
// CHECK-NEXT:   Name: foo
// CHECK-NEXT:   Value: 0x11000
// CHECK-NEXT:   Size: 0
// CHECK-NEXT:   Binding: Global
// CHECK-NEXT:   Type: GNU_IFunc
// CHECK-NEXT:   Other: 0
// CHECK-NEXT:   Section: .text
// CHECK-NEXT: }
// CHECK-NEXT:]

// DISASM: Disassembly of section .text:
// DISASM-NEXT: foo:
// DISASM-NEXT:    11000: c3 retl
// DISASM: bar:
// DISASM-NEXT:    11001: c3 retl
// DISASM:      _start:
// DISASM-NEXT:    11002: e8 19 00 00 00 calll 25
// DISASM-NEXT:    11007: e8 24 00 00 00 calll 36
// DISASM-NEXT:    1100c: ba d4 00 01 00 movl $65748, %edx
// DISASM-NEXT:    11011: ba e4 00 01 00 movl $65764, %edx
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-NEXT: .plt:
// DISASM-NEXT:    11020: ff 25 00 20 01 00 jmpl *73728
// DISASM-NEXT:    11026: 68 10 00 00 00 pushl $16
// DISASM-NEXT:    1102b: e9 e0 ff ff ff jmp -32 <_start+0xe>
// DISASM-NEXT:    11030: ff 25 04 20 01 00 jmpl *73732
// DISASM-NEXT:    11036: 68 18 00 00 00 pushl $24
// DISASM-NEXT:    1103b: e9 d0 ff ff ff jmp -48 <_start+0xe>

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
 call foo
 call bar
 movl $__rel_iplt_start,%edx
 movl $__rel_iplt_end,%edx
