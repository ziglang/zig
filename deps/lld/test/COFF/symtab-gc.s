# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %tobject.obj %S/Inputs/object.s
# RUN: lld-link -dll -entry:f -out:%t.dll -implib:%t.lib %tobject.obj
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %tmain.obj %s
# RUN: lld-link -entry:main -out:%t.exe -opt:ref -debug:dwarf %tmain.obj %t.lib
# RUN: llvm-readobj -coff-imports %t.exe | FileCheck %s

# CHECK-NOT: Symbol: f

	.def	 main;
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,main
	.globl	main
main:
	retq

	.def	 stripped;
	.scl	3;
	.type	32;
	.endef
	.section	.text,"xr",one_only,stripped
stripped:
	callq	__imp_f
	retq
