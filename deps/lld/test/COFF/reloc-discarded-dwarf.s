# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t1.obj %s
# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t2.obj %s

# LLD should not error on relocations in DWARF debug sections against symbols in
# discarded sections.
# RUN: lld-link -entry:main -debug %t1.obj %t2.obj

	.section	.text,"xr",discard,main
	.globl	main
main:
f:
	retq

	.section	.debug_info,"dr"
	.quad	f
	.section	.eh_frame,"dr"
	.quad	f
