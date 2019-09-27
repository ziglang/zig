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
// RUN: ld.lld -shared %t1.o %t2.so -o %t.exe -z retpolineplt -z now --script %t.script
// RUN: llvm-objdump -d -s %t.exe | FileCheck %s

// CHECK:      Disassembly of section .plt:
// CHECK-EMPTY:
// CHECK-NEXT: .plt:
// CHECK-NEXT: 10:	e8 0b 00 00 00 	callq	11 <.plt+0x10>
// CHECK-NEXT: 15:	f3 90 	pause
// CHECK-NEXT: 17:	0f ae e8 	lfence
// CHECK-NEXT: 1a:	eb f9 	jmp	-7 <.plt+0x5>
// CHECK-NEXT: 1c:	cc 	int3
// CHECK-NEXT: 1d:	cc 	int3
// CHECK-NEXT: 1e:	cc 	int3
// CHECK-NEXT: 1f:	cc 	int3
// CHECK-NEXT: 20:	4c 89 1c 24 	movq	%r11, (%rsp)
// CHECK-NEXT: 24:	c3 	retq
// CHECK-NEXT: 25:	cc 	int3
// CHECK-NEXT: 26:	cc 	int3
// CHECK-NEXT: 27:	cc 	int3
// CHECK-NEXT: 28:	cc 	int3
// CHECK-NEXT: 29:	cc 	int3
// CHECK-NEXT: 2a:	cc 	int3
// CHECK-NEXT: 2b:	cc 	int3
// CHECK-NEXT: 2c:	cc 	int3
// CHECK-NEXT: 2d:	cc 	int3
// CHECK-NEXT: 2e:	cc 	int3
// CHECK-NEXT: 2f:	cc 	int3
// CHECK-NEXT: 30:	4c 8b 1d 31 00 00 00 	movq	49(%rip), %r11
// CHECK-NEXT: 37:	e9 d4 ff ff ff 	jmp	-44 <.plt>
// CHECK-NEXT: 3c:	cc 	int3
// CHECK-NEXT: 3d:	cc 	int3
// CHECK-NEXT: 3e:	cc 	int3
// CHECK-NEXT: 3f:	cc 	int3
// CHECK-NEXT: 40:      4c 8b 1d 29 00 00 00 	movq	41(%rip), %r11
// CHECK-NEXT: 47:	e9 c4 ff ff ff 	jmp	-60 <.plt>
// CHECK-NEXT: 4c:	cc 	int3
// CHECK-NEXT: 4d:	cc 	int3
// CHECK-NEXT: 4e:	cc 	int3
// CHECK-NEXT: 4f:	cc 	int3

.global _start
_start:
  jmp bar@PLT
  jmp zed@PLT
