// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-pc-freebsd %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-pc-freebsd %p/Inputs/plt-aarch64.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld -shared %t.o %t2.so -o %t.so
// RUN: ld.lld %t.o %t2.so -o %t.exe
// RUN: llvm-readobj -S -r %t.so | FileCheck --check-prefix=CHECKDSO %s
// RUN: llvm-objdump -s -section=.got.plt %t.so | FileCheck --check-prefix=DUMPDSO %s
// RUN: llvm-objdump -d %t.so | FileCheck --check-prefix=DISASMDSO %s
// RUN: llvm-readobj -S -r %t.exe | FileCheck --check-prefix=CHECKEXE %s
// RUN: llvm-objdump -s -section=.got.plt %t.exe | FileCheck --check-prefix=DUMPEXE %s
// RUN: llvm-objdump -d %t.exe | FileCheck --check-prefix=DISASMEXE %s

// CHECKDSO:     Name: .plt
// CHECKDSO-NEXT:     Type: SHT_PROGBITS
// CHECKDSO-NEXT:     Flags [
// CHECKDSO-NEXT:       SHF_ALLOC
// CHECKDSO-NEXT:       SHF_EXECINSTR
// CHECKDSO-NEXT:     ]
// CHECKDSO-NEXT:     Address: 0x10010
// CHECKDSO-NEXT:     Offset:
// CHECKDSO-NEXT:     Size: 80
// CHECKDSO-NEXT:     Link:
// CHECKDSO-NEXT:     Info:
// CHECKDSO-NEXT:     AddressAlignment: 16

// CHECKDSO:     Name: .got.plt
// CHECKDSO-NEXT:     Type: SHT_PROGBITS
// CHECKDSO-NEXT:     Flags [
// CHECKDSO-NEXT:       SHF_ALLOC
// CHECKDSO-NEXT:       SHF_WRITE
// CHECKDSO-NEXT:     ]
// CHECKDSO-NEXT:     Address: 0x30000
// CHECKDSO-NEXT:     Offset:
// CHECKDSO-NEXT:     Size: 48
// CHECKDSO-NEXT:     Link:
// CHECKDSO-NEXT:     Info:
// CHECKDSO-NEXT:     AddressAlignment: 8

// CHECKDSO: Relocations [
// CHECKDSO-NEXT:   Section ({{.*}}) .rela.plt {

// &(.got.plt[3]) = 0x30000 + 3 * 8 = 0x30018
// CHECKDSO-NEXT:     0x30018 R_AARCH64_JUMP_SLOT foo

// &(.got.plt[4]) = 0x30000 + 4 * 8 = 0x30020
// CHECKDSO-NEXT:     0x30020 R_AARCH64_JUMP_SLOT bar

// &(.got.plt[5]) = 0x30000 + 5 * 8 = 0x30028
// CHECKDSO-NEXT:     0x30028 R_AARCH64_JUMP_SLOT weak
// CHECKDSO-NEXT:   }
// CHECKDSO-NEXT: ]

// DUMPDSO: Contents of section .got.plt:
// .got.plt[0..2] = 0 (reserved)
// .got.plt[3..5] = .plt = 0x10010
// DUMPDSO-NEXT: 30000 00000000 00000000 00000000 00000000  ................
// DUMPDSO-NEXT: 30010 00000000 00000000 10000100 00000000  ................
// DUMPDSO-NEXT: 30020 10000100 00000000 10000100 00000000  ................

// DISASMDSO: _start:
// 0x10030 - 0x10000 = 0x30 = 48
// DISASMDSO-NEXT:     10000:	0c 00 00 14 	b	#48
// 0x10040 - 0x10004 = 0x3c = 60
// DISASMDSO-NEXT:     10004:	0f 00 00 14 	b	#60
// 0x10050 - 0x10008 = 0x48 = 72
// DISASMDSO-NEXT:     10008:	12 00 00 14 	b	#72

// DISASMDSO: foo:
// DISASMDSO-NEXT:     1000c:	1f 20 03 d5 	nop

// DISASMDSO: Disassembly of section .plt:
// DISASMDSO-EMPTY:
// DISASMDSO-NEXT: .plt:
// DISASMDSO-NEXT:     10010:	f0 7b bf a9 	stp	x16, x30, [sp, #-16]!
// &(.got.plt[2]) = 0x3000 + 2 * 8 = 0x3010
// Page(0x30010) - Page(0x10014) = 0x30000 - 0x10000 = 0x20000 = 131072
// DISASMDSO-NEXT:     10014:	10 01 00 90 	adrp	x16, #131072
// 0x3010 & 0xFFF = 0x10 = 16
// DISASMDSO-NEXT:     10018:	11 0a 40 f9 ldr x17, [x16, #16]
// DISASMDSO-NEXT:     1001c:	10 42 00 91 	add	x16, x16, #16
// DISASMDSO-NEXT:     10020:	20 02 1f d6 	br	x17
// DISASMDSO-NEXT:     10024:	1f 20 03 d5 	nop
// DISASMDSO-NEXT:     10028:	1f 20 03 d5 	nop
// DISASMDSO-NEXT:     1002c:	1f 20 03 d5 	nop

// foo@plt
// Page(0x30018) - Page(0x10030) = 0x30000 - 0x10000 = 0x20000 = 131072
// DISASMDSO-EMPTY:
// DISASMDSO-NEXT:   foo@plt:
// DISASMDSO-NEXT:     10030:	10 01 00 90 	adrp	x16, #131072
// 0x3018 & 0xFFF = 0x18 = 24
// DISASMDSO-NEXT:     10034:	11 0e 40 f9 	ldr	x17, [x16, #24]
// DISASMDSO-NEXT:     10038:	10 62 00 91 	add	x16, x16, #24
// DISASMDSO-NEXT:     1003c:	20 02 1f d6 	br	x17

// bar@plt
// Page(0x30020) - Page(0x10040) = 0x30000 - 0x10000 = 0x20000 = 131072
// DISASMDSO-EMPTY:
// DISASMDSO-NEXT:   bar@plt:
// DISASMDSO-NEXT:     10040:	10 01 00 90 	adrp	x16, #131072
// 0x3020 & 0xFFF = 0x20 = 32
// DISASMDSO-NEXT:     10044:	11 12 40 f9 	ldr	x17, [x16, #32]
// DISASMDSO-NEXT:     10048:	10 82 00 91 	add	x16, x16, #32
// DISASMDSO-NEXT:     1004c:	20 02 1f d6 	br	x17

// weak@plt
// Page(0x30028) - Page(0x10050) = 0x30000 - 0x10000 = 0x20000 = 131072
// DISASMDSO-EMPTY:
// DISASMDSO-NEXT:   weak@plt:
// DISASMDSO-NEXT:     10050:	10 01 00 90 	adrp	x16, #131072
// 0x3028 & 0xFFF = 0x28 = 40
// DISASMDSO-NEXT:     10054:	11 16 40 f9 	ldr	x17, [x16, #40]
// DISASMDSO-NEXT:     10058:	10 a2 00 91 	add	x16, x16, #40
// DISASMDSO-NEXT:     1005c:	20 02 1f d6 	br	x17

// CHECKEXE:     Name: .plt
// CHECKEXE-NEXT:     Type: SHT_PROGBITS
// CHECKEXE-NEXT:     Flags [
// CHECKEXE-NEXT:       SHF_ALLOC
// CHECKEXE-NEXT:       SHF_EXECINSTR
// CHECKEXE-NEXT:     ]
// CHECKEXE-NEXT:     Address: 0x210010
// CHECKEXE-NEXT:     Offset:
// CHECKEXE-NEXT:     Size: 64
// CHECKEXE-NEXT:     Link:
// CHECKEXE-NEXT:     Info:
// CHECKEXE-NEXT:     AddressAlignment: 16

// CHECKEXE:     Name: .got.plt
// CHECKEXE-NEXT:     Type: SHT_PROGBITS
// CHECKEXE-NEXT:     Flags [
// CHECKEXE-NEXT:       SHF_ALLOC
// CHECKEXE-NEXT:       SHF_WRITE
// CHECKEXE-NEXT:     ]
// CHECKEXE-NEXT:     Address: 0x230000
// CHECKEXE-NEXT:     Offset:
// CHECKEXE-NEXT:     Size: 40
// CHECKEXE-NEXT:     Link:
// CHECKEXE-NEXT:     Info:
// CHECKEXE-NEXT:     AddressAlignment: 8

// CHECKEXE: Relocations [
// CHECKEXE-NEXT:   Section ({{.*}}) .rela.plt {

// &(.got.plt[3]) = 0x230000 + 3 * 8 = 0x230018
// CHECKEXE-NEXT:     0x230018 R_AARCH64_JUMP_SLOT bar 0x0

// &(.got.plt[4]) = 0x230000 + 4 * 8 = 0x230020
// CHECKEXE-NEXT:     0x230020 R_AARCH64_JUMP_SLOT weak 0x0
// CHECKEXE-NEXT:   }
// CHECKEXE-NEXT: ]

// DUMPEXE: Contents of section .got.plt:
// .got.plt[0..2] = 0 (reserved)
// .got.plt[3..4] = .plt = 0x40010
// DUMPEXE-NEXT:  230000 00000000 00000000 00000000 00000000
// DUMPEXE-NEXT:  230010 00000000 00000000 10002100 00000000
// DUMPEXE-NEXT:  230020 10002100 00000000

// DISASMEXE: _start:
// 0x21000c - 0x210000 = 0xc = 12
// DISASMEXE-NEXT:    210000:	03 00 00 14 	b	#12
// 0x210030 - 0x210004 = 0x2c = 44
// DISASMEXE-NEXT:    210004:	0b 00 00 14 	b	#44
// 0x210040 - 0x210008 = 0x38 = 56
// DISASMEXE-NEXT:    210008:	0e 00 00 14 	b	#56

// DISASMEXE: foo:
// DISASMEXE-NEXT:    21000c:	1f 20 03 d5 	nop

// DISASMEXE: Disassembly of section .plt:
// DISASMEXE-EMPTY:
// DISASMEXE-NEXT: .plt:
// DISASMEXE-NEXT:    210010:	f0 7b bf a9 	stp	x16, x30, [sp, #-16]!
// &(.got.plt[2]) = 0x2200B0 + 2 * 8 = 0x2200C0
// Page(0x230010) - Page(0x210014) = 0x230000 - 0x210000 = 0x20000 = 131072
// DISASMEXE-NEXT:    210014:	10 01 00 90  	adrp	x16, #131072
// 0x120c0 & 0xFFF = 0xC0 = 192
// DISASMEXE-NEXT:    210018:	11 0a 40 f9 	ldr	x17, [x16, #16]
// DISASMEXE-NEXT:    21001c:	10 42 00 91 	add	x16, x16, #16
// DISASMEXE-NEXT:    210020:	20 02 1f d6 	br	x17
// DISASMEXE-NEXT:    210024:	1f 20 03 d5 	nop
// DISASMEXE-NEXT:    210028:	1f 20 03 d5 	nop
// DISASMEXE-NEXT:    21002c:	1f 20 03 d5 	nop

// bar@plt
// Page(0x230018) - Page(0x210030) = 0x230000 - 0x210000 = 0x20000 = 131072
// DISASMEXE-EMPTY:
// DISASMEXE-NEXT:   bar@plt:
// DISASMEXE-NEXT:    210030:	10 01 00 90 	adrp	x16, #131072
// DISASMEXE-NEXT:    210034:	11 0e 40 f9 	ldr	x17, [x16, #24]
// DISASMEXE-NEXT:    210038:	10 62 00 91 	add	x16, x16, #24
// DISASMEXE-NEXT:    21003c:	20 02 1f d6 	br	x17

// weak@plt
// Page(0x230020) - Page(0x210040) = 0x230000 - 0x210000 = 0x20000 = 131072
// DISASMEXE-EMPTY:
// DISASMEXE-NEXT:   weak@plt:
// DISASMEXE-NEXT:    210040:	10 01 00 90 	adrp	x16, #131072
// DISASMEXE-NEXT:    210044:	11 12 40 f9 	ldr	x17, [x16, #32]
// DISASMEXE-NEXT:    210048:	10 82 00 91 	add	x16, x16, #32
// DISASMEXE-NEXT:    21004c:	20 02 1f d6 	br	x17

.global _start,foo,bar
.weak weak
_start:
  b foo
  b bar
  b weak

.section .text2,"ax",@progbits
foo:
  nop
