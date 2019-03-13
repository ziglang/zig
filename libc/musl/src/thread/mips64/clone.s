.set	noreorder
.global	__clone
.hidden __clone
.type	__clone,@function
__clone:
	# Save function pointer and argument pointer on new thread stack
	and	$5, $5, -16	# aligning stack to double word
	dsubu	$5, $5, 16
	sd	$4, 0($5)	# save function pointer
	sd	$7, 8($5)	# save argument pointer

	# Shuffle (fn,sp,fl,arg,ptid,tls,ctid) to (fl,sp,ptid,tls,ctid)
	# sys_clone(u64 flags, u64 ustack_base, u64 parent_tidptr, u64 child_tidptr, u64 tls)
	move	$4, $6
	move	$6, $8
	move	$7, $9
	move	$8, $10
	li	$2, 5055
	syscall
	beq	$7, $0, 1f
	nop
	jr	$ra
	dsubu	$2, $0, $2
1:	beq	$2, $0, 1f
	nop
	jr	$ra
	nop
1:	ld	$25, 0($sp)	# function pointer
	ld	$4, 8($sp)	# argument pointer
	jalr	$25		# call the user's function
	nop
	move 	$4, $2
	li	$2, 5058
	syscall
