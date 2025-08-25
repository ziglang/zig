	.global __restore
	.hidden __restore
	.type __restore,%function
__restore:
	li      0, 119 #__NR_sigreturn
	sc

	.global __restore_rt
	.hidden __restore_rt
	.type __restore_rt,%function
__restore_rt:
	li      0, 172 # __NR_rt_sigreturn
	sc
