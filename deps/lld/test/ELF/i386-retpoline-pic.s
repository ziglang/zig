// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux -position-independent %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux -position-independent %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so

// RUN: ld.lld %t1.o %t2.so -o %t.exe -z retpolineplt -pie
// RUN: llvm-objdump -d -s %t.exe | FileCheck %s

// CHECK:      Disassembly of section .plt:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 1010:       ff b3 04 20 00 00       pushl   8196(%ebx)
// CHECK-NEXT: 1016:       50      pushl   %eax
// CHECK-NEXT: 1017:       8b 83 08 20 00 00       movl    8200(%ebx), %eax
// CHECK-NEXT: 101d:       e8 0e 00 00 00  calll   14 <.plt+0x20>
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
// CHECK-NEXT: 1030:       89 0c 24        movl    %ecx, (%esp)
// CHECK-NEXT: 1033:       8b 4c 24 04     movl    4(%esp), %ecx
// CHECK-NEXT: 1037:       89 44 24 04     movl    %eax, 4(%esp)
// CHECK-NEXT: 103b:       89 c8   movl    %ecx, %eax
// CHECK-NEXT: 103d:       59      popl    %ecx
// CHECK-NEXT: 103e:       c3      retl
// CHECK-NEXT: 103f:       cc      int3
// CHECK-NEXT: 1040:       50      pushl   %eax
// CHECK-NEXT: 1041:       8b 83 0c 20 00 00       movl    8204(%ebx), %eax
// CHECK-NEXT: 1047:       e8 e4 ff ff ff  calll   -28 <.plt+0x20>
// CHECK-NEXT: 104c:       e9 d1 ff ff ff  jmp     -47 <.plt+0x12>
// CHECK-NEXT: 1051:       68 00 00 00 00  pushl   $0
// CHECK-NEXT: 1056:       e9 b5 ff ff ff  jmp     -75 <.plt>
// CHECK-NEXT: 105b:       cc      int3
// CHECK-NEXT: 105c:       cc      int3
// CHECK-NEXT: 105d:       cc      int3
// CHECK-NEXT: 105e:       cc      int3
// CHECK-NEXT: 105f:       cc      int3
// CHECK-NEXT: 1060:       50      pushl   %eax
// CHECK-NEXT: 1061:       8b 83 10 20 00 00       movl    8208(%ebx), %eax
// CHECK-NEXT: 1067:       e8 c4 ff ff ff  calll   -60 <.plt+0x20>
// CHECK-NEXT: 106c:       e9 b1 ff ff ff  jmp     -79 <.plt+0x12>
// CHECK-NEXT: 1071:       68 08 00 00 00  pushl   $8
// CHECK-NEXT: 1076:       e9 95 ff ff ff  jmp     -107 <.plt>
// CHECK-NEXT: 107b:       cc      int3
// CHECK-NEXT: 107c:       cc      int3
// CHECK-NEXT: 107d:       cc      int3
// CHECK-NEXT: 107e:       cc      int3
// CHECK-NEXT: 107f:       cc      int3

// CHECK:      Contents of section .got.plt:
// CHECK-NEXT: 2000 00300000 00000000 00000000 51100000
// CHECK-NEXT: 2010 71100000

.global _start
_start:
  jmp bar@PLT
  jmp zed@PLT
