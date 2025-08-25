	.global __cp_begin
	.hidden __cp_begin
	.global __cp_end
	.hidden __cp_end
	.global __cp_cancel
	.hidden __cp_cancel
	.hidden __cancel
	.global __syscall_cp_asm
	.hidden __syscall_cp_asm
	.text
	.type   __syscall_cp_asm,%function
__syscall_cp_asm:
	# at enter: r3 = pointer to self->cancel, r4: syscall no, r5: first arg, r6: 2nd, r7: 3rd, r8: 4th, r9: 5th, r10: 6th
__cp_begin:
	# if (self->cancel) goto __cp_cancel
	lwz   0, 0(3)
	cmpwi cr7, 0, 0
	bne-  cr7, __cp_cancel

	# make syscall
	mr    0,  4
	mr    3,  5
	mr    4,  6
	mr    5,  7
	mr    6,  8
	mr    7,  9
	mr    8, 10
	sc

__cp_end:
	# return error ? -r3 : r3
	bnslr+
	neg 3, 3
	blr

__cp_cancel:
	mflr 0
	bl 1f
	.long .TOC.-.
1:	mflr 3
	lwa 2, 0(3)
	add 2, 2, 3
	mtlr 0
	b __cancel
