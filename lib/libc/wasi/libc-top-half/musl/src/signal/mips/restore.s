.set noreorder

.global __restore_rt
.hidden __restore_rt
.type   __restore_rt,@function
__restore_rt:
	li $2, 4193
	syscall

.global __restore
.hidden __restore
.type   __restore,@function
__restore:
	li $2, 4119
	syscall
