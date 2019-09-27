// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so

// RUN: ld.lld -shared %t1.o %t2.so -o %t.exe -z retpolineplt -z now
// RUN: llvm-objdump -d -s %t.exe | FileCheck %s

// CHECK:      Disassembly of section .plt:
// CHECK-EMPTY:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 1010:	e8 0b 00 00 00 	callq	11 <.plt+0x10>
// CHECK-NEXT: 1015:	f3 90 	pause
// CHECK-NEXT: 1017:	0f ae e8 	lfence
// CHECK-NEXT: 101a:	eb f9 	jmp	-7 <.plt+0x5>
// CHECK-NEXT: 101c:	cc 	int3
// CHECK-NEXT: 101d:	cc 	int3
// CHECK-NEXT: 101e:	cc 	int3
// CHECK-NEXT: 101f:	cc 	int3
// CHECK-NEXT: 1020:	4c 89 1c 24 	movq	%r11, (%rsp)
// CHECK-NEXT: 1024:	c3 	retq
// CHECK-NEXT: 1025:	cc 	int3
// CHECK-NEXT: 1026:	cc 	int3
// CHECK-NEXT: 1027:	cc 	int3
// CHECK-NEXT: 1028:	cc 	int3
// CHECK-NEXT: 1029:	cc 	int3
// CHECK-NEXT: 102a:	cc 	int3
// CHECK-NEXT: 102b:	cc 	int3
// CHECK-NEXT: 102c:	cc 	int3
// CHECK-NEXT: 102d:	cc 	int3
// CHECK-NEXT: 102e:	cc 	int3
// CHECK-NEXT: 102f:	cc 	int3
// CHECK-NEXT: 1030:	4c 8b 1d c1 10 00 00 	movq	4289(%rip), %r11
// CHECK-NEXT: 1037:	e9 d4 ff ff ff 	jmp	-44 <.plt>
// CHECK-NEXT: 103c:	cc 	int3
// CHECK-NEXT: 103d:	cc 	int3
// CHECK-NEXT: 103e:	cc 	int3
// CHECK-NEXT: 103f:	cc 	int3
// CHECK-NEXT: 1040:	4c 8b 1d b9 10 00 00 	movq	4281(%rip), %r11
// CHECK-NEXT: 1047:	e9 c4 ff ff ff 	jmp	-60 <.plt>
// CHECK-NEXT: 104c:	cc 	int3
// CHECK-NEXT: 104d:	cc 	int3
// CHECK-NEXT: 104e:	cc 	int3
// CHECK-NEXT: 104f:	cc 	int3

// CHECK:      Contents of section .got.plt:
// CHECK-NEXT: 20e0 00200000 00000000 00000000 00000000
// CHECK-NEXT: 20f0 00000000 00000000 00000000 00000000
// CHECK-NEXT: 2100 00000000 00000000

.global _start
_start:
  jmp bar@PLT
  jmp zed@PLT
