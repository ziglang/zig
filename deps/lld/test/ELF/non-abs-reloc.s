// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t 2>&1 | FileCheck %s
// CHECK: (.nonalloc+0x1): has non-ABS relocation R_X86_64_PC32 against symbol '_start'
// CHECK: (.nonalloc+0x6): has non-ABS relocation R_X86_64_PC32 against symbol '_start'

// RUN: llvm-objdump -D %t | FileCheck --check-prefix=DISASM %s
// DISASM:      Disassembly of section .nonalloc:
// DISASM-NEXT: .nonalloc:
// DISASM-NEXT: 0: {{.*}}  callq {{.*}} <_start>
// DISASM-NEXT: 5: {{.*}}  callq {{.*}} <_start>

.globl _start
_start:
  nop

.section .nonalloc
  .byte 0xe8
  .long _start - . - 4
  .byte 0xe8
  .long _start - . - 4
