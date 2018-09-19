// Input file generated with:
// llvm33/llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %S/Inputs/llvm33-rela-outside-group.o
//
// RUN: ld.lld -shared %S/Inputs/llvm33-rela-outside-group.o %S/Inputs/llvm33-rela-outside-group.o -o /dev/null

	.global bar
	.weak	_Z3fooIiEvv

	.section	.text._Z3fooIiEvv,"axG",@progbits,_Z3fooIiEvv,comdat
_Z3fooIiEvv:
	callq	bar@PLT
