# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/x86-64-split-stack-main.s -o %t2.o

# RUN: ld.lld --defsym __morestack=0x100 --defsym __morestack_non_split=0x200 %t1.o %t2.o -o %t
# RUN: llvm-objdump -d %t 2>&1 | FileCheck %s

# An unknown prologue ordinarily gives a match failure, except that this
# object file includes a .note.GNU-no-split-stack section, which tells the
# linker to expect such prologues, and therefore not error.

# CHECK: __morestack

	.text

	.global	unknown_prologue
	.type	unknown_prologue,@function
unknown_prologue:
	push %rbp
	mov %rsp,%rbp
	cmp %fs:0x70,%rsp
	jae 1f
	callq __morestack
	retq
1:
	callq non_split
	leaveq
	retq

	.size unknown_prologue,. - unknown_prologue
	.section .note.GNU-split-stack,"",@progbits
	.section .note.GNU-no-split-stack,"",@progbits
