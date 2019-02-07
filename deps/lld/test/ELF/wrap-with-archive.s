// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/wrap-with-archive.s -o %t2
// RUN: llvm-ar rcs %t3 %t2
// RUN: ld.lld -o %t4 %t %t3 -wrap get_executable_start

// Regression test for https://bugs.llvm.org/show_bug.cgi?id=40134
	
.global get_executable_start
.global _start

_start:
	jmp get_executable_start
