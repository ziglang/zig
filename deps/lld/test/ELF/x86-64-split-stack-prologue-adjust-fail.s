# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/x86-64-split-stack-extra.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/x86-64-split-stack-main.s -o %t3.o

# RUN: not ld.lld --defsym __morestack=0x100 --defsym __more_stack_nonsplit=0x200 %t1.o %t2.o %t3.o -o %t 2>&1 | FileCheck %s

# An unknown prologue gives a match failure
# CHECK: error: {{.*}}.o:(.text): unknown_prologue (with -fsplit-stack) calls non_split (without -fsplit-stack), but couldn't adjust its prologue

# RUN: not ld.lld -r --defsym __morestack=0x100 %t1.o %t2.o -o %t 2>&1 | FileCheck %s -check-prefix=RELOCATABLE
# RELOCATABLE: cannot mix split-stack and non-split-stack in a relocatable link

# RUN: not ld.lld --defsym __morestack=0x100 --defsym _start=0x300 %t1.o %t2.o %t3.o -o %t 2>&1 | FileCheck %s -check-prefix=ERROR
# ERROR: Mixing split-stack objects requires a definition of __morestack_non_split

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
