// TODO - Test this if sa_restorer is ever supported in our kernel
.global __restore
.type __restore,%function
.global __restore_rt
.type __restore_rt,%function
__restore:
__restore_rt:
	r6 = #139				// SYS_rt_sigreturn
	trap0(#0)
.size __restore, .-__restore
.size __restore_rt, .-__restore_rt
