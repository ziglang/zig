# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/x86-64-split-stack-extra.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/x86-64-split-stack-main.s -o %t3.o

# RUN: ld.lld --defsym __morestack=0x100 --defsym __morestack_non_split=0x200 %t1.o %t2.o %t3.o -o %t -z notext
# RUN: llvm-objdump -d %t | FileCheck %s

# Avoid duplicating the prologue for every test via macros.

.macro prologue1 function_to_call
	.global	prologue1_calls_\function_to_call
	.type	prologue1_calls_\function_to_call,@function
prologue1_calls_\function_to_call:
	cmp %fs:0x70,%rsp
	jae 1f
	callq __morestack
	retq
1:
	# Various and duplicate calls to ensure every code path is taken.
	callq \function_to_call
	callq \function_to_call
	callq 1b
	callq non_function_text_symbol
	retq
	.size	prologue1_calls_\function_to_call,. - prologue1_calls_\function_to_call
.endm

.macro prologue2 function_to_call register compare_amount
	.global	prologue2_calls_\function_to_call\register
	.type	prologue2_calls_\function_to_call\register,@function
prologue2_calls_\function_to_call\register:
	lea	-\compare_amount(%rsp),%\register
	cmp	%fs:0x70,%\register
	jae	1f
	callq	__morestack
	retq
1:
	# Various and duplicate calls to ensure every code path is taken.
	callq	\function_to_call
	callq	\function_to_call
	callq 1b
	callq non_function_text_symbol
	retq
	.size	prologue2_calls_\function_to_call\register,. - prologue2_calls_\function_to_call\register
.endm

	.local foo
foo:
	.section .text,"ax",@progbits
	.quad foo

	.text

# For split-stack code calling split-stack code, ensure prologue v1 still
# calls plain __morestack, and that any raw bytes written to the prologue
# make sense.
# CHECK: prologue1_calls_split:
# CHECK-NEXT: cmp{{.*}}%fs:{{[^,]*}},{{.*}}%rsp
# CHECK: jae{{.*$}}
# CHECK-NEXT: callq{{.*}}<__morestack>

prologue1 split

# For split-stack code calling split-stack code, ensure prologue v2 still
# calls plain __morestack, that any raw bytes written to the prologue
# make sense, and that the register number is preserved.
# CHECK: prologue2_calls_splitr10:
# CHECK-NEXT: lea{{.*}} -512(%rsp),{{.*}}%r10
# CHECK: cmp{{.*}}%fs:{{[^,]*}},{{.*}}%r{{[0-9]+}}
# CHECK: jae{{.*}}
# CHECK-NEXT: callq{{.*}}<__morestack>

prologue2 split r10 0x200

# CHECK: prologue2_calls_splitr11:
# CHECK-NEXT: lea{{.*}} -256(%rsp),{{.*}}%r11
# CHECK: cmp{{.*}}%fs:{{[^,]*}},{{.*}}%r{{[0-9]+}}
# CHECK: jae{{.*}}
# CHECK-NEXT: callq{{.*}}<__morestack>

prologue2 split r11 0x100

# For split-stack code calling non-split-stack code, ensure prologue v1
# calls __morestack_non_split, and that any raw bytes written to the prologue
# make sense.
# CHECK: prologue1_calls_non_split:
# CHECK-NEXT: stc{{.*$}}
# CHECK-NEXT: nopl{{.*$}}
# CHECK: jae{{.*$}}
# CHECK-NEXT: callq{{.*}}<__morestack_non_split>

prologue1 non_split

# For split-stack code calling non-split-stack code, ensure prologue v2
# calls __morestack_non_split, that any raw bytes written to the prologue
# make sense, and that the register number is preserved
# CHECK: prologue2_calls_non_splitr10:
# CHECK-NEXT: lea{{.*}} -16640(%rsp),{{.*}}%r10
# CHECK: cmp{{.*}}%fs:{{[^,]*}},{{.*}}%r10
# CHECK: jae{{.*$}}
# CHECK-NEXT: callq{{.*}}<__morestack_non_split>

prologue2 non_split r10 0x100

# CHECK: prologue2_calls_non_splitr11:
# CHECK-NEXT: lea{{.*}} -16896(%rsp),{{.*}}%r11
# CHECK: cmp{{.*}}%fs:{{[^,]*}},{{.*}}%r11
# CHECK: jae{{.*$}}
# CHECK-NEXT: callq{{.*}}<__morestack_non_split>

prologue2 non_split r11 0x200

	.section	.note.GNU-stack,"",@progbits
	.section	.note.GNU-split-stack,"",@progbits
