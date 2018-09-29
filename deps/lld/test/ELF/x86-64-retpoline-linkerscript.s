// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so

// RUN: echo "SECTIONS { \
// RUN:   .text : { *(.text) } \
// RUN:   .plt : { *(.plt) } \
// RUN:   .got.plt : { *(.got.plt) } \
// RUN:   .dynstr : { *(.dynstr) } \
// RUN: }" > %t.script
// RUN: ld.lld -shared %t1.o %t2.so -o %t.exe -z retpolineplt --script %t.script
// RUN: llvm-objdump -d -s %t.exe | FileCheck %s

// CHECK:      Disassembly of section .plt:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 10:       ff 35 72 00 00 00       pushq   114(%rip)
// CHECK-NEXT: 16:       4c 8b 1d 73 00 00 00    movq    115(%rip), %r11
// CHECK-NEXT: 1d:       e8 0e 00 00 00  callq   14 <.plt+0x20>
// CHECK-NEXT: 22:       f3 90   pause
// CHECK-NEXT: 24:       0f ae e8        lfence
// CHECK-NEXT: 27:       eb f9   jmp     -7 <.plt+0x12>
// CHECK-NEXT: 29:       cc      int3
// CHECK-NEXT: 2a:       cc      int3
// CHECK-NEXT: 2b:       cc      int3
// CHECK-NEXT: 2c:       cc      int3
// CHECK-NEXT: 2d:       cc      int3
// CHECK-NEXT: 2e:       cc      int3
// CHECK-NEXT: 2f:       cc      int3
// CHECK-NEXT: 30:       4c 89 1c 24     movq    %r11, (%rsp)
// CHECK-NEXT: 34:       c3      retq
// CHECK-NEXT: 35:       cc      int3
// CHECK-NEXT: 36:       cc      int3
// CHECK-NEXT: 37:       cc      int3
// CHECK-NEXT: 38:       cc      int3
// CHECK-NEXT: 39:       cc      int3
// CHECK-NEXT: 3a:       cc      int3
// CHECK-NEXT: 3b:       cc      int3
// CHECK-NEXT: 3c:       cc      int3
// CHECK-NEXT: 3d:       cc      int3
// CHECK-NEXT: 3e:       cc      int3
// CHECK-NEXT: 3f:       cc      int3
// CHECK-NEXT: 40:       4c 8b 1d 51 00 00 00    movq    81(%rip), %r11
// CHECK-NEXT: 47:       e8 e4 ff ff ff  callq   -28 <.plt+0x20>
// CHECK-NEXT: 4c:       e9 d1 ff ff ff  jmp     -47 <.plt+0x12>
// CHECK-NEXT: 51:       68 00 00 00 00  pushq   $0
// CHECK-NEXT: 56:       e9 b5 ff ff ff  jmp     -75 <.plt>
// CHECK-NEXT: 5b:       cc      int3
// CHECK-NEXT: 5c:       cc      int3
// CHECK-NEXT: 5d:       cc      int3
// CHECK-NEXT: 5e:       cc      int3
// CHECK-NEXT: 5f:       cc      int3
// CHECK-NEXT: 60:       4c 8b 1d 39 00 00 00    movq    57(%rip), %r11
// CHECK-NEXT: 67:       e8 c4 ff ff ff  callq   -60 <.plt+0x20>
// CHECK-NEXT: 6c:       e9 b1 ff ff ff  jmp     -79 <.plt+0x12>
// CHECK-NEXT: 71:       68 01 00 00 00  pushq   $1
// CHECK-NEXT: 76:       e9 95 ff ff ff  jmp     -107 <.plt>
// CHECK-NEXT: 7b:       cc      int3
// CHECK-NEXT: 7c:       cc      int3
// CHECK-NEXT: 7d:       cc      int3
// CHECK-NEXT: 7e:       cc      int3
// CHECK-NEXT: 7f:       cc      int3

.global _start
_start:
  jmp bar@PLT
  jmp zed@PLT
