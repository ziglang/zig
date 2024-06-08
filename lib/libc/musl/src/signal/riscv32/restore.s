.global __restore
.type __restore, %function
__restore:
.global __restore_rt
.type __restore_rt, %function
__restore_rt:
	li a7, 139 # SYS_rt_sigreturn
	ecall
