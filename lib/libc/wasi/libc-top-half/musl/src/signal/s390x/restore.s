	.global __restore
	.hidden __restore
	.type __restore,%function
__restore:
	svc 119 #__NR_sigreturn

	.global __restore_rt
	.hidden __restore_rt
	.type __restore_rt,%function
__restore_rt:
	svc 173 # __NR_rt_sigreturn
