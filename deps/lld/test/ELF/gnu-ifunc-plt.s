// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/shared2-x86-64.s -o %t1.o
// RUN: ld.lld %t1.o --shared -o %t.so
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv %t.so %t.o -o %tout
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-objdump -s %tout | FileCheck %s --check-prefix=GOTPLT
// RUN: llvm-readobj -r -dynamic-table %tout | FileCheck %s

// Check that the IRELATIVE relocations are after the JUMP_SLOT in the plt
// CHECK: Relocations [
// CHECK-NEXT:   Section (4) .rela.plt {
// CHECK-NEXT:     0x202018 R_X86_64_JUMP_SLOT bar2 0x0
// CHECK-NEXT:     0x202020 R_X86_64_JUMP_SLOT zed2 0x0
// CHECK-NEXT:     0x202028 R_X86_64_IRELATIVE - 0x201000
// CHECK-NEXT:     0x202030 R_X86_64_IRELATIVE - 0x201001

// Check that .got.plt entries point back to PLT header
// GOTPLT: Contents of section .got.plt:
// GOTPLT-NEXT:  202000 00302000 00000000 00000000 00000000
// GOTPLT-NEXT:  202010 00000000 00000000 36102000 00000000
// GOTPLT-NEXT:  202020 46102000 00000000 56102000 00000000
// GOTPLT-NEXT:  202030 66102000 00000000

// Check that the PLTRELSZ tag includes the IRELATIVE relocations
// CHECK: DynamicSection [
// CHECK:   0x0000000000000002 PLTRELSZ             96 (bytes)

// Check that a PLT header is written and the ifunc entries appear last
// DISASM: Disassembly of section .text:
// DISASM-NEXT: foo:
// DISASM-NEXT:   201000:       c3      retq
// DISASM:      bar:
// DISASM-NEXT:   201001:       c3      retq
// DISASM:      _start:
// DISASM-NEXT:   201002:       e8 49 00 00 00          callq   73
// DISASM-NEXT:   201007:       e8 54 00 00 00          callq   84
// DISASM-NEXT:   20100c:       e8 1f 00 00 00          callq   31
// DISASM-NEXT:   201011:       e8 2a 00 00 00          callq   42
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-NEXT: .plt:
// DISASM-NEXT:   201020:       ff 35 e2 0f 00 00       pushq   4066(%rip)
// DISASM-NEXT:   201026:       ff 25 e4 0f 00 00       jmpq    *4068(%rip)
// DISASM-NEXT:   20102c:       0f 1f 40 00     nopl    (%rax)
// DISASM-NEXT:   201030:       ff 25 e2 0f 00 00       jmpq    *4066(%rip)
// DISASM-NEXT:   201036:       68 00 00 00 00          pushq   $0
// DISASM-NEXT:   20103b:       e9 e0 ff ff ff          jmp     -32 <.plt>
// DISASM-NEXT:   201040:       ff 25 da 0f 00 00       jmpq    *4058(%rip)
// DISASM-NEXT:   201046:       68 01 00 00 00          pushq   $1
// DISASM-NEXT:   20104b:       e9 d0 ff ff ff          jmp     -48 <.plt>
// DISASM-NEXT:   201050:       ff 25 d2 0f 00 00       jmpq    *4050(%rip)
// DISASM-NEXT:   201056:       68 00 00 00 00          pushq   $0
// DISASM-NEXT:   20105b:       e9 e0 ff ff ff          jmp     -32 <.plt+0x20>
// DISASM-NEXT:   201060:       ff 25 ca 0f 00 00       jmpq    *4042(%rip)
// DISASM-NEXT:   201066:       68 01 00 00 00          pushq   $1
// DISASM-NEXT:   20106b:       e9 d0 ff ff ff          jmp     -48 <.plt+0x20>

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
 call bar2
 call zed2
