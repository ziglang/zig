// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so

// RUN: ld.lld %t1.o %t2.so -o %t.exe -z retpolineplt
// RUN: llvm-objdump -d -s %t.exe | FileCheck %s

// CHECK:      Disassembly of section .plt:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 401010:       ff 35 04 20 40 00       pushl   4202500
// CHECK-NEXT: 401016:       50      pushl   %eax
// CHECK-NEXT: 401017:       a1 08 20 40 00  movl    4202504, %eax
// CHECK-NEXT: 40101c:       e8 0f 00 00 00  calll   15 <.plt+0x20>
// CHECK-NEXT: 401021:       f3 90   pause
// CHECK-NEXT: 401023:       0f ae e8        lfence
// CHECK-NEXT: 401026:       eb f9   jmp     -7 <.plt+0x11>
// CHECK-NEXT: 401028:       cc      int3
// CHECK-NEXT: 401029:       cc      int3
// CHECK-NEXT: 40102a:       cc      int3
// CHECK-NEXT: 40102b:       cc      int3
// CHECK-NEXT: 40102c:       cc      int3
// CHECK-NEXT: 40102d:       cc      int3
// CHECK-NEXT: 40102e:       cc      int3
// CHECK-NEXT: 40102f:       cc      int3
// CHECK-NEXT: 401030:       89 0c 24        movl    %ecx, (%esp)
// CHECK-NEXT: 401033:       8b 4c 24 04     movl    4(%esp), %ecx
// CHECK-NEXT: 401037:       89 44 24 04     movl    %eax, 4(%esp)
// CHECK-NEXT: 40103b:       89 c8   movl    %ecx, %eax
// CHECK-NEXT: 40103d:       59      popl    %ecx
// CHECK-NEXT: 40103e:       c3      retl
// CHECK-NEXT: 40103f:       cc      int3
// CHECK-NEXT: 401040:       50      pushl   %eax
// CHECK-NEXT: 401041:       a1 0c 20 40 00  movl    4202508, %eax
// CHECK-NEXT: 401046:       e8 e5 ff ff ff  calll   -27 <.plt+0x20>
// CHECK-NEXT: 40104b:       e9 d1 ff ff ff  jmp     -47 <.plt+0x11>
// CHECK-NEXT: 401050:       68 00 00 00 00  pushl   $0
// CHECK-NEXT: 401055:       e9 b6 ff ff ff  jmp     -74 <.plt>
// CHECK-NEXT: 40105a:       cc      int3
// CHECK-NEXT: 40105b:       cc      int3
// CHECK-NEXT: 40105c:       cc      int3
// CHECK-NEXT: 40105d:       cc      int3
// CHECK-NEXT: 40105e:       cc      int3
// CHECK-NEXT: 40105f:       cc      int3
// CHECK-NEXT: 401060:       50      pushl   %eax
// CHECK-NEXT: 401061:       a1 10 20 40 00  movl    4202512, %eax
// CHECK-NEXT: 401066:       e8 c5 ff ff ff  calll   -59 <.plt+0x20>
// CHECK-NEXT: 40106b:       e9 b1 ff ff ff  jmp     -79 <.plt+0x11>
// CHECK-NEXT: 401070:       68 08 00 00 00  pushl   $8
// CHECK-NEXT: 401075:       e9 96 ff ff ff  jmp     -106 <.plt>
// CHECK-NEXT: 40107a:       cc      int3
// CHECK-NEXT: 40107b:       cc      int3
// CHECK-NEXT: 40107c:       cc      int3
// CHECK-NEXT: 40107d:       cc      int3
// CHECK-NEXT: 40107e:       cc      int3
// CHECK-NEXT: 40107f:       cc      int3

// CHECK:      Contents of section .got.plt:
// CHECK-NEXT: 00304000 00000000 00000000 50104000
// CHECK-NEXT: 70104000

.global _start
_start:
  jmp bar@PLT
  jmp zed@PLT
