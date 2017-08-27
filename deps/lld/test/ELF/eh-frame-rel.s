// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: ld.lld %t.o %t.o -o %t -shared
// We used to try to read the relocations as RELA and error out

	.cfi_startproc
	.cfi_endproc
