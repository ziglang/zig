.set	noreorder
.global	__clone
.hidden __clone
.type	__clone,@function
__clone:
	# Save function pointer and argument pointer on new thread stack
	and	$5, $5, -16	# aligning stack to double word
	subu	$5, $5, 16
	sw	$4, 0($5)	# save function pointer
	sw	$7, 4($5)	# save argument pointer

	# Shuffle (fn,sp,fl,arg,ptid,tls,ctid) to (fl,sp,ptid,tls,ctid)
	# sys_clone(u64 flags, u64 ustack_base, u64 parent_tidptr, u64 child_tidptr, u64 tls)
	move	$4, $6
	move	$6, $8
	move	$7, $9
	move	$8, $10
	li	$2, 6055
	syscall
	beq	$7, $0, 1f
	nop
	jr	$ra
	subu	$2, $0, $2
1:	beq	$2, $0, 1f
	nop
	jr	$ra
	nop
1:	lw	$25, 0($sp)	# function pointer
	lw	$4, 4($sp)	# argument pointer
	jalr	$25		# call the user's function
	nop
	move 	$4, $2
	li	$2, 6058
	syscall
