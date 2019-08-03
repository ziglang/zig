// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so

// RUN: ld.lld -shared %t1.o %t2.so -o %t.exe -z retpolineplt
// RUN: llvm-objdump -d -s %t.exe | FileCheck %s

// CHECK:      Disassembly of section .plt:
// CHECK-EMPTY:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 1010:       ff 35 f2 1f 00 00       pushq   8178(%rip)
// CHECK-NEXT: 1016:       4c 8b 1d f3 1f 00 00    movq    8179(%rip), %r11
// CHECK-NEXT: 101d:       e8 0e 00 00 00  callq   14 <.plt+0x20>
// CHECK-NEXT: 1022:       f3 90   pause
// CHECK-NEXT: 1024:       0f ae e8        lfence
// CHECK-NEXT: 1027:       eb f9   jmp     -7 <.plt+0x12>
// CHECK-NEXT: 1029:       cc      int3
// CHECK-NEXT: 102a:       cc      int3
// CHECK-NEXT: 102b:       cc      int3
// CHECK-NEXT: 102c:       cc      int3
// CHECK-NEXT: 102d:       cc      int3
// CHECK-NEXT: 102e:       cc      int3
// CHECK-NEXT: 102f:       cc      int3
// CHECK-NEXT: 1030:       4c 89 1c 24     movq    %r11, (%rsp)
// CHECK-NEXT: 1034:       c3      retq
// CHECK-NEXT: 1035:       cc      int3
// CHECK-NEXT: 1036:       cc      int3
// CHECK-NEXT: 1037:       cc      int3
// CHECK-NEXT: 1038:       cc      int3
// CHECK-NEXT: 1039:       cc      int3
// CHECK-NEXT: 103a:       cc      int3
// CHECK-NEXT: 103b:       cc      int3
// CHECK-NEXT: 103c:       cc      int3
// CHECK-NEXT: 103d:       cc      int3
// CHECK-NEXT: 103e:       cc      int3
// CHECK-NEXT: 103f:       cc      int3
// CHECK-NEXT: 1040:       4c 8b 1d d1 1f 00 00    movq    8145(%rip), %r11
// CHECK-NEXT: 1047:       e8 e4 ff ff ff  callq   -28 <.plt+0x20>
// CHECK-NEXT: 104c:       e9 d1 ff ff ff  jmp     -47 <.plt+0x12>
// CHECK-NEXT: 1051:       68 00 00 00 00  pushq   $0
// CHECK-NEXT: 1056:       e9 b5 ff ff ff  jmp     -75 <.plt>
// CHECK-NEXT: 105b:       cc      int3
// CHECK-NEXT: 105c:       cc      int3
// CHECK-NEXT: 105d:       cc      int3
// CHECK-NEXT: 105e:       cc      int3
// CHECK-NEXT: 105f:       cc      int3
// CHECK-NEXT: 1060:       4c 8b 1d b9 1f 00 00    movq    8121(%rip), %r11
// CHECK-NEXT: 1067:       e8 c4 ff ff ff  callq   -60 <.plt+0x20>
// CHECK-NEXT: 106c:       e9 b1 ff ff ff  jmp     -79 <.plt+0x12>
// CHECK-NEXT: 1071:       68 01 00 00 00  pushq   $1
// CHECK-NEXT: 1076:       e9 95 ff ff ff  jmp     -107 <.plt>
// CHECK-NEXT: 107b:       cc      int3
// CHECK-NEXT: 107c:       cc      int3
// CHECK-NEXT: 107d:       cc      int3
// CHECK-NEXT: 107e:       cc      int3
// CHECK-NEXT: 107f:       cc      int3

// CHECK:      Contents of section .got.plt:
// CHECK-NEXT: 3000 00200000 00000000 00000000 00000000
// CHECK-NEXT: 3010 00000000 00000000 51100000 00000000
// CHECK-NEXT: 3020 71100000 00000000

.global _start
_start:
  jmp bar@PLT
  jmp zed@PLT
