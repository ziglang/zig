# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/x86-64-split-stack-extra.s -o %t2.o
# RUN: ld.lld --defsym __morestack=0x100 --defsym __morestack_non_split=0x200 %t2.o -o %t4.so  -shared

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld --defsym __morestack=0x100 --defsym __morestack_non_split=0x200 %t1.o %t4.so -o %t
# RUN: llvm-objdump -d %t | FileCheck %s

# For a cross .so call, make sure lld produced the conservative call to __morestack_non_split.
# CHECK: prologue1_cross_so_call:
# CHECK-NEXT: stc{{.*$}}
# CHECK-NEXT: nopl{{.*$}}
# CHECK: jae{{.*$}}
# CHECK-NEXT: callq{{.*}}<__morestack_non_split>

	.text

	.global	prologue1_cross_so_call
	.type	prologue1_cross_so_call,@function
prologue1_cross_so_call:
	cmp %fs:0x70,%rsp
	jae 1f
	callq __morestack
	retq
1:
	callq split
	retq
	.size	prologue1_cross_so_call,. - prologue1_cross_so_call

	.section	.note.GNU-stack,"",@progbits
	.section	.note.GNU-split-stack,"",@progbits
