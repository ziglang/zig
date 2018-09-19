// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: ld.lld -r %t.o -o %t2.o
// RUN: ld.lld -shared %t2.o -o /dev/null

// We used to crash using the output of -r because of the relative order of
// SHF_LINK_ORDER sections.

// That can be fixed by changing -r or making the regular link more flexible,
// so this is an end to end test.

	.fnstart
	.fnend
