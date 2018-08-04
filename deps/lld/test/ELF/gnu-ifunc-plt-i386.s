// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %S/Inputs/shared2-x86-64.s -o %t1.o
// RUN: ld.lld %t1.o --shared -o %t.so
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv %t.so %t.o -o %tout
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-objdump -s %tout | FileCheck %s --check-prefix=GOTPLT
// RUN: llvm-readobj -r -dynamic-table %tout | FileCheck %s

// Check that the IRELATIVE relocations are after the JUMP_SLOT in the plt
// CHECK: Relocations [
// CHECK-NEXT:   Section (4) .rel.plt {
// CHECK-NEXT:     0x1200C R_386_JUMP_SLOT bar2
// CHECK-NEXT:     0x12010 R_386_JUMP_SLOT zed2
// CHECK-NEXT:     0x12014 R_386_IRELATIVE
// CHECK-NEXT:     0x12018 R_386_IRELATIVE

// Check that IRELATIVE .got.plt entries point to ifunc resolver and not
// back to the plt entry + 6.
// GOTPLT: Contents of section .got.plt:
// GOTPLT:       12000 00300100 00000000 00000000 36100100
// GOTPLT-NEXT:  12010 46100100 00100100 01100100

// Check that the PLTRELSZ tag includes the IRELATIVE relocations
// CHECK: DynamicSection [
// CHECK:  0x00000002 PLTRELSZ             32 (bytes)

// Check that a PLT header is written and the ifunc entries appear last
// DISASM: Disassembly of section .text:
// DISASM-NEXT: foo:
// DISASM-NEXT:    11000:       c3      retl
// DISASM:      bar:
// DISASM-NEXT:    11001:       c3      retl
// DISASM:      _start:
// DISASM-NEXT:    11002:       e8 49 00 00 00          calll   73
// DISASM-NEXT:    11007:       e8 54 00 00 00          calll   84
// DISASM-NEXT:    1100c:       e8 1f 00 00 00          calll   31
// DISASM-NEXT:    11011:       e8 2a 00 00 00          calll   42
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-NEXT: .plt:
// DISASM-NEXT:    11020:       ff 35 04 20 01 00       pushl   73732
// DISASM-NEXT:    11026:       ff 25 08 20 01 00       jmpl    *73736
// DISASM-NEXT:    1102c:       90      nop
// DISASM-NEXT:    1102d:       90      nop
// DISASM-NEXT:    1102e:       90      nop
// DISASM-NEXT:    1102f:       90      nop
// DISASM-NEXT:    11030:       ff 25 0c 20 01 00       jmpl    *73740
// DISASM-NEXT:    11036:       68 00 00 00 00          pushl   $0
// DISASM-NEXT:    1103b:       e9 e0 ff ff ff          jmp     -32 <.plt>
// DISASM-NEXT:    11040:       ff 25 10 20 01 00       jmpl    *73744
// DISASM-NEXT:    11046:       68 08 00 00 00          pushl   $8
// DISASM-NEXT:    1104b:       e9 d0 ff ff ff          jmp     -48 <.plt>
// DISASM-NEXT:    11050:       ff 25 14 20 01 00       jmpl    *73748
// DISASM-NEXT:    11056:       68 30 00 00 00          pushl   $48
// DISASM-NEXT:    1105b:       e9 e0 ff ff ff          jmp     -32 <.plt+0x20>
// DISASM-NEXT:    11060:       ff 25 18 20 01 00       jmpl    *73752
// DISASM-NEXT:    11066:       68 38 00 00 00          pushl   $56
// DISASM-NEXT:    1106b:       e9 d0 ff ff ff          jmp     -48 <.plt+0x20>

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
 call foo@plt
 call bar@plt
 call bar2@plt
 call zed2@plt
