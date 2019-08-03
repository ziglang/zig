// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %S/Inputs/shared2-x86-64.s -o %t1.o
// RUN: ld.lld %t1.o --shared -o %t.so
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv %t.so %t.o -o %tout
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-objdump -s %tout | FileCheck %s --check-prefix=GOTPLT
// RUN: llvm-readobj -r --dynamic-table %tout | FileCheck %s

// Check that the IRELATIVE relocations are after the JUMP_SLOT in the plt
// CHECK: Relocations [
// CHECK-NEXT:   Section (4) .rel.plt {
// CHECK-NEXT:     0x40300C R_386_JUMP_SLOT bar2
// CHECK-NEXT:     0x403010 R_386_JUMP_SLOT zed2
// CHECK-NEXT:     0x403014 R_386_IRELATIVE
// CHECK-NEXT:     0x403018 R_386_IRELATIVE

// Check that IRELATIVE .got.plt entries point to ifunc resolver and not
// back to the plt entry + 6.
// GOTPLT: Contents of section .got.plt:
// GOTPLT:       403000 00204000 00000000 00000000 36104000
// GOTPLT-NEXT:  403010 46104000 00104000 01104000

// Check that the PLTRELSZ tag includes the IRELATIVE relocations
// CHECK: DynamicSection [
// CHECK:  0x00000002 PLTRELSZ             32 (bytes)

// Check that a PLT header is written and the ifunc entries appear last
// DISASM: Disassembly of section .text:
// DISASM-EMPTY:
// DISASM-NEXT: foo:
// DISASM-NEXT:    401000:       c3      retl
// DISASM:      bar:
// DISASM-NEXT:    401001:       c3      retl
// DISASM:      _start:
// DISASM-NEXT:    401002:       e8 49 00 00 00          calll   73
// DISASM-NEXT:    401007:       e8 54 00 00 00          calll   84
// DISASM-NEXT:    40100c:       e8 1f 00 00 00          calll   31
// DISASM-NEXT:    401011:       e8 2a 00 00 00          calll   42
// DISASM-EMPTY:
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-EMPTY:
// DISASM-NEXT: .plt:
// DISASM-NEXT:    401020:       ff 35 04 30 40 00       pushl   4206596
// DISASM-NEXT:    401026:       ff 25 08 30 40 00       jmpl    *4206600
// DISASM-NEXT:    40102c:       90      nop
// DISASM-NEXT:    40102d:       90      nop
// DISASM-NEXT:    40102e:       90      nop
// DISASM-NEXT:    40102f:       90      nop
// DISASM-EMPTY:
// DISASM-NEXT:   bar2@plt:
// DISASM-NEXT:    401030:       ff 25 0c 30 40 00       jmpl    *4206604
// DISASM-NEXT:    401036:       68 00 00 00 00          pushl   $0
// DISASM-NEXT:    40103b:       e9 e0 ff ff ff          jmp     -32 <.plt>
// DISASM-EMPTY:
// DISASM-NEXT:   zed2@plt:
// DISASM-NEXT:    401040:       ff 25 10 30 40 00       jmpl    *4206608
// DISASM-NEXT:    401046:       68 08 00 00 00          pushl   $8
// DISASM-NEXT:    40104b:       e9 d0 ff ff ff          jmp     -48 <.plt>
// DISASM-NEXT:    401050:       ff 25 14 30 40 00       jmpl    *4206612
// DISASM-NEXT:    401056:       68 30 00 00 00          pushl   $48
// DISASM-NEXT:    40105b:       e9 e0 ff ff ff          jmp     -32 <zed2@plt>
// DISASM-NEXT:    401060:       ff 25 18 30 40 00       jmpl    *4206616
// DISASM-NEXT:    401066:       68 38 00 00 00          pushl   $56
// DISASM-NEXT:    40106b:       e9 d0 ff ff ff          jmp     -48 <zed2@plt>

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
