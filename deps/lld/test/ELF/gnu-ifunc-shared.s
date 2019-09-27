// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv --shared -o %t.so %t.o
// RUN: llvm-objdump -d %t.so | FileCheck %s --check-prefix=DISASM
// RUN: llvm-readobj -r %t.so | FileCheck %s

// Check that an IRELATIVE relocation is used for a non-preemptible ifunc
// handler and a JUMP_SLOT is used for a preemptible ifunc
// DISASM: Disassembly of section .text:
// DISASM-EMPTY:
// DISASM-NEXT: fct:
// DISASM-NEXT:     1000:       c3      retq
// DISASM:     fct2:
// DISASM-NEXT:     1001:       c3      retq
// DISASM:     f1:
// DISASM-NEXT:     1002:       e8 49 00 00 00          callq   73
// DISASM-NEXT:     1007:       e8 24 00 00 00          callq   36
// DISASM-NEXT:     100c:       e8 2f 00 00 00          callq   47
// DISASM-NEXT:     1011:       c3      retq
// DISASM:     f2:
// DISASM-NEXT:     1012:       c3      retq
// DISASM-EMPTY:
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-EMPTY:
// DISASM-NEXT: .plt:
// DISASM-NEXT:     1020:       ff 35 e2 1f 00 00       pushq   8162(%rip)
// DISASM-NEXT:     1026:       ff 25 e4 1f 00 00       jmpq    *8164(%rip)
// DISASM-NEXT:     102c:       0f 1f 40 00     nopl    (%rax)
// DISASM-EMPTY:
// DISASM-NEXT:   fct2@plt:
// DISASM-NEXT:     1030:       ff 25 e2 1f 00 00       jmpq    *8162(%rip)
// DISASM-NEXT:     1036:       68 00 00 00 00          pushq   $0
// DISASM-NEXT:     103b:       e9 e0 ff ff ff          jmp     -32 <.plt>
// DISASM-EMPTY:
// DISASM-NEXT:   f2@plt:
// DISASM-NEXT:     1040:       ff 25 da 1f 00 00       jmpq    *8154(%rip)
// DISASM-NEXT:     1046:       68 01 00 00 00          pushq   $1
// DISASM-NEXT:     104b:       e9 d0 ff ff ff          jmp     -48 <.plt>
// DISASM-NEXT:     1050:       ff 25 d2 1f 00 00       jmpq    *8146(%rip)
// DISASM-NEXT:     1056:       68 00 00 00 00          pushq   $0
// DISASM-NEXT:     105b:       e9 e0 ff ff ff          jmp     -32 <f2@plt>

// CHECK: Relocations [
// CHECK-NEXT:   Section (4) .rela.plt {
// CHECK-NEXT:     0x3018 R_X86_64_JUMP_SLOT fct2 0x0
// CHECK-NEXT:     0x3020 R_X86_64_JUMP_SLOT f2 0x0
// CHECK-NEXT:     0x3028 R_X86_64_IRELATIVE - 0x1000

 // Hidden expect IRELATIVE
 .globl fct
 .hidden fct
 .type  fct, STT_GNU_IFUNC
fct:
 ret

 // Not hidden expect JUMP_SLOT
 .globl fct2
 .type  fct2, STT_GNU_IFUNC
fct2:
 ret

 .globl f1
 .type f1, @function
f1:
 call fct
 call fct2
 call f2@PLT
 ret

 .globl f2
 .type f2, @function
f2:
 ret
