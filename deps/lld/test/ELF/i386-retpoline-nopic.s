// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so

// RUN: ld.lld %t1.o %t2.so -o %t.exe -z retpolineplt
// RUN: llvm-objdump -d -s %t.exe | FileCheck %s

// CHECK:      Disassembly of section .plt:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 11010:       ff 35 04 20 01 00       pushl   73732
// CHECK-NEXT: 11016:       50      pushl   %eax
// CHECK-NEXT: 11017:       a1 08 20 01 00  movl    73736, %eax
// CHECK-NEXT: 1101c:       e8 0f 00 00 00  calll   15 <.plt+0x20>
// CHECK-NEXT: 11021:       f3 90   pause
// CHECK-NEXT: 11023:       0f ae e8        lfence
// CHECK-NEXT: 11026:       eb f9   jmp     -7 <.plt+0x11>
// CHECK-NEXT: 11028:       cc      int3
// CHECK-NEXT: 11029:       cc      int3
// CHECK-NEXT: 1102a:       cc      int3
// CHECK-NEXT: 1102b:       cc      int3
// CHECK-NEXT: 1102c:       cc      int3
// CHECK-NEXT: 1102d:       cc      int3
// CHECK-NEXT: 1102e:       cc      int3
// CHECK-NEXT: 1102f:       cc      int3
// CHECK-NEXT: 11030:       89 0c 24        movl    %ecx, (%esp)
// CHECK-NEXT: 11033:       8b 4c 24 04     movl    4(%esp), %ecx
// CHECK-NEXT: 11037:       89 44 24 04     movl    %eax, 4(%esp)
// CHECK-NEXT: 1103b:       89 c8   movl    %ecx, %eax
// CHECK-NEXT: 1103d:       59      popl    %ecx
// CHECK-NEXT: 1103e:       c3      retl
// CHECK-NEXT: 1103f:       cc      int3
// CHECK-NEXT: 11040:       50      pushl   %eax
// CHECK-NEXT: 11041:       a1 0c 20 01 00  movl    73740, %eax
// CHECK-NEXT: 11046:       e8 e5 ff ff ff  calll   -27 <.plt+0x20>
// CHECK-NEXT: 1104b:       e9 d1 ff ff ff  jmp     -47 <.plt+0x11>
// CHECK-NEXT: 11050:       68 00 00 00 00  pushl   $0
// CHECK-NEXT: 11055:       e9 b6 ff ff ff  jmp     -74 <.plt>
// CHECK-NEXT: 1105a:       cc      int3
// CHECK-NEXT: 1105b:       cc      int3
// CHECK-NEXT: 1105c:       cc      int3
// CHECK-NEXT: 1105d:       cc      int3
// CHECK-NEXT: 1105e:       cc      int3
// CHECK-NEXT: 1105f:       cc      int3
// CHECK-NEXT: 11060:       50      pushl   %eax
// CHECK-NEXT: 11061:       a1 10 20 01 00  movl    73744, %eax
// CHECK-NEXT: 11066:       e8 c5 ff ff ff  calll   -59 <.plt+0x20>
// CHECK-NEXT: 1106b:       e9 b1 ff ff ff  jmp     -79 <.plt+0x11>
// CHECK-NEXT: 11070:       68 08 00 00 00  pushl   $8
// CHECK-NEXT: 11075:       e9 96 ff ff ff  jmp     -106 <.plt>
// CHECK-NEXT: 1107a:       cc      int3
// CHECK-NEXT: 1107b:       cc      int3
// CHECK-NEXT: 1107c:       cc      int3
// CHECK-NEXT: 1107d:       cc      int3
// CHECK-NEXT: 1107e:       cc      int3
// CHECK-NEXT: 1107f:       cc      int3

// CHECK:      Contents of section .got.plt:
// CHECK-NEXT: 00300100 00000000 00000000 50100100
// CHECK-NEXT: 70100100

.global _start
_start:
  jmp bar@PLT
  jmp zed@PLT
