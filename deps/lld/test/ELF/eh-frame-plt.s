// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/shared.s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
// RUN: ld.lld %t2.o %t.so -o %t
// RUN: llvm-readobj -r %t | FileCheck %s

	.globl	_start
_start:
	.cfi_startproc
	.cfi_personality 3, bar
	.cfi_endproc

// CHECK:      Section ({{.*}}) .rela.plt {
// CHECK-NEXT:   R_X86_64_JUMP_SLOT bar 0x0
// CHECK-NEXT: }
