# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/x86-64-split-stack-main.s -o %t2.o

# RUN: not ld.lld --defsym __morestack=0x100 %t1.o %t2.o -o %t 2>&1 | FileCheck %s

# An unknown prologue gives a match failure
# CHECK: unable to adjust the enclosing function's

# RUN: not ld.lld -r --defsym __morestack=0x100 %t1.o %t2.o -o %t 2>&1 | FileCheck %s -check-prefix=RELOCATABLE
# RELOCATABLE: Cannot mix split-stack and non-split-stack in a relocatable link

	.text

	.global	unknown_prologue
	.type	unknown_prologue,@function
unknown_prologue:
	push	%rbp
	mov	%rsp,%rbp
	cmp	%fs:0x70,%rsp
	jae	1f
	callq	__morestack
	retq
1:
	callq	non_split
	leaveq
	retq

	.size	unknown_prologue,. - unknown_prologue

	.section	.note.GNU-split-stack,"",@progbits
