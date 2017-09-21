# RUN: echo -e '.section .bss,"bw",discard,main_global\n.global main_global\n main_global:\n .long 0' | \
# RUN:     llvm-mc - -filetype=obj -o %t1.obj -triple x86_64-windows-msvc
# RUN: llvm-mc %s -filetype=obj -o %t2.obj -triple x86_64-windows-msvc

# LLD should report an error and not assert regardless of whether we are doing
# GC.

# RUN: not lld-link -entry:main -nodefaultlib %t1.obj %t2.obj -out:%t.exe -opt:ref   2>&1 | FileCheck %s
# RUN: not lld-link -entry:main -nodefaultlib %t1.obj %t2.obj -out:%t.exe -opt:noref 2>&1 | FileCheck %s

# CHECK: error: relocation against symbol in discarded section: assoc_global

	.section	.bss,"bw",discard,main_global
	.globl	main_global
	.p2align	2
main_global:
	.long	0

	.section	.CRT$XCU,"dr",associative,main_global
	.p2align	3
	.globl assoc_global
assoc_global:
	.quad	main_global

	.text
	.globl main
main:
	movq assoc_global(%rip), %rax
	movl (%rax), %eax
	retq
