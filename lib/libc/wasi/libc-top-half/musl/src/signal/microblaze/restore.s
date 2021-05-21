.global __restore
.hidden __restore
.type __restore,@function
__restore:
	ori     r12, r0, 119
	brki    r14, 0x8

.global __restore_rt
.hidden __restore_rt
.type __restore_rt,@function
__restore_rt:
	ori     r12, r0, 173
	brki    r14, 0x8
