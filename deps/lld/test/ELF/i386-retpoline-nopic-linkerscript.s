// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so

// RUN: echo "SECTIONS { \
// RUN:   .text : { *(.text) } \
// RUN:   .plt : { *(.plt) } \
// RUN:   .got.plt : { *(.got.plt) } \
// RUN:   .dynstr : { *(.dynstr) } \
// RUN: }" > %t.script
// RUN: ld.lld %t1.o %t2.so -o %t.exe -z retpolineplt --script %t.script
// RUN: llvm-objdump -d -s %t.exe | FileCheck %s

// CHECK:      Disassembly of section .plt:
// CHECK-EMPTY:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 10:       ff 35 ec 00 00 00       pushl   236
// CHECK-NEXT: 16:       50      pushl   %eax
// CHECK-NEXT: 17:       a1 f0 00 00 00 movl    240, %eax
// CHECK-NEXT: 1c:       e8 0f 00 00 00  calll   15 <.plt+0x20>
// CHECK-NEXT: 21:       f3 90   pause
// CHECK-NEXT: 23:       0f ae e8        lfence
// CHECK-NEXT: 26:       eb f9   jmp     -7 <.plt+0x11>
// CHECK-NEXT: 28:       cc      int3
// CHECK-NEXT: 29:       cc      int3
// CHECK-NEXT: 2a:       cc      int3
// CHECK-NEXT: 2b:       cc      int3
// CHECK-NEXT: 2c:       cc      int3
// CHECK-NEXT: 2d:       cc      int3
// CHECK-NEXT: 2e:       cc      int3
// CHECK-NEXT: 2f:       cc      int3
// CHECK-NEXT: 30:       89 0c 24        movl    %ecx, (%esp)
// CHECK-NEXT: 33:       8b 4c 24 04     movl    4(%esp), %ecx
// CHECK-NEXT: 37:       89 44 24 04     movl    %eax, 4(%esp)
// CHECK-NEXT: 3b:       89 c8   movl    %ecx, %eax
// CHECK-NEXT: 3d:       59      popl    %ecx
// CHECK-NEXT: 3e:       c3      retl
// CHECK-NEXT: 3f:       cc      int3
// CHECK-NEXT: 40:       50      pushl   %eax
// CHECK-NEXT: 41:       a1 f4 00 00 00  movl    244, %eax
// CHECK-NEXT: 46:       e8 e5 ff ff ff  calll   -27 <.plt+0x20>
// CHECK-NEXT: 4b:       e9 d1 ff ff ff  jmp     -47 <.plt+0x11>
// CHECK-NEXT: 50:       68 00 00 00 00  pushl   $0
// CHECK-NEXT: 55:       e9 b6 ff ff ff  jmp     -74 <.plt>
// CHECK-NEXT: 5a:       cc      int3
// CHECK-NEXT: 5b:       cc      int3
// CHECK-NEXT: 5c:       cc      int3
// CHECK-NEXT: 5d:       cc      int3
// CHECK-NEXT: 5e:       cc      int3
// CHECK-NEXT: 5f:       cc      int3
// CHECK-NEXT: 60:       50      pushl   %eax
// CHECK-NEXT: 61:       a1 f8 00 00 00  movl    248, %eax
// CHECK-NEXT: 66:       e8 c5 ff ff ff  calll   -59 <.plt+0x20>
// CHECK-NEXT: 6b:       e9 b1 ff ff ff  jmp     -79 <.plt+0x11>
// CHECK-NEXT: 70:       68 08 00 00 00  pushl   $8
// CHECK-NEXT: 75:       e9 96 ff ff ff  jmp     -106 <.plt>
// CHECK-NEXT: 7a:       cc      int3
// CHECK-NEXT: 7b:       cc      int3
// CHECK-NEXT: 7c:       cc      int3
// CHECK-NEXT: 7d:       cc      int3
// CHECK-NEXT: 7e:       cc      int3
// CHECK-NEXT: 7f:       cc      int3

.global _start
_start:
  jmp bar@PLT
  jmp zed@PLT
