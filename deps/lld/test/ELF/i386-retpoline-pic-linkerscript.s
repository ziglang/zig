// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux -position-independent %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux -position-independent %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so

// RUN: echo "SECTIONS { \
// RUN:   .text : { *(.text) } \
// RUN:   .plt : { *(.plt) } \
// RUN:   .got.plt : { *(.got.plt) } \
// RUN:   .dynstr : { *(.dynstr) } \
// RUN: }" > %t.script
// RUN: ld.lld %t1.o %t2.so -o %t.exe -z retpolineplt -pie --script %t.script
// RUN: llvm-objdump -d -s %t.exe | FileCheck %s

// CHECK:      Disassembly of section .plt:
// CHECK-EMPTY:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 10:       ff b3 04 00 00 00       pushl   4(%ebx)
// CHECK-NEXT: 16:       50      pushl   %eax
// CHECK-NEXT: 17:       8b 83 08 00 00 00 movl    8(%ebx), %eax
// CHECK-NEXT: 1d:       e8 0e 00 00 00  calll   14 <.plt+0x20>
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
// CHECK-NEXT: 30:       89 0c 24        movl    %ecx, (%esp)
// CHECK-NEXT: 33:       8b 4c 24 04     movl    4(%esp), %ecx
// CHECK-NEXT: 37:       89 44 24 04     movl    %eax, 4(%esp)
// CHECK-NEXT: 3b:       89 c8   movl    %ecx, %eax
// CHECK-NEXT: 3d:       59      popl    %ecx
// CHECK-NEXT: 3e:       c3      retl
// CHECK-NEXT: 3f:       cc      int3
// CHECK-NEXT: 40:       50      pushl   %eax
// CHECK-NEXT: 41:       8b 83 0c 00 00 00       movl    12(%ebx), %eax
// CHECK-NEXT: 47:       e8 e4 ff ff ff  calll   -28 <.plt+0x20>
// CHECK-NEXT: 4c:       e9 d1 ff ff ff  jmp     -47 <.plt+0x12>
// CHECK-NEXT: 51:       68 00 00 00 00  pushl   $0
// CHECK-NEXT: 56:       e9 b5 ff ff ff  jmp     -75 <.plt>
// CHECK-NEXT: 5b:       cc      int3
// CHECK-NEXT: 5c:       cc      int3
// CHECK-NEXT: 5d:       cc      int3
// CHECK-NEXT: 5e:       cc      int3
// CHECK-NEXT: 5f:       cc      int3
// CHECK-NEXT: 60:       50      pushl   %eax
// CHECK-NEXT: 61:       8b 83 10 00 00 00       movl    16(%ebx), %eax
// CHECK-NEXT: 67:       e8 c4 ff ff ff  calll   -60 <.plt+0x20>
// CHECK-NEXT: 6c:       e9 b1 ff ff ff  jmp     -79 <.plt+0x12>
// CHECK-NEXT: 71:       68 08 00 00 00  pushl   $8
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
