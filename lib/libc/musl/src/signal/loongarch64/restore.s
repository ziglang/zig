.global __restore_rt
.global __restore
.hidden __restore_rt
.hidden __restore
.type   __restore_rt,@function
.type   __restore,@function
__restore_rt:
__restore:
	li.w    $a7, 139
	syscall 0
