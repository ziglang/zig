.set    noreorder

.global __syscall
.hidden __syscall
.type   __syscall,@function
__syscall:
	move    $2, $4
	move    $4, $5
	move    $5, $6
	move    $6, $7
	lw      $7, 16($sp)
	lw      $8, 20($sp)
	lw      $9, 24($sp)
	lw      $10,28($sp)
	subu    $sp, $sp, 32
	sw      $8, 16($sp)
	sw      $9, 20($sp)
	sw      $10,24($sp)
	sw      $2 ,28($sp)
	lw      $2, 28($sp)
	syscall
	beq     $7, $0, 1f
	addu    $sp, $sp, 32
	subu    $2, $0, $2
1:	jr      $ra
	nop
