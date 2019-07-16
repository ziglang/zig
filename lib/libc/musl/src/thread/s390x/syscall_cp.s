	.global __cp_begin
	.hidden __cp_begin
	.global __cp_end
	.hidden __cp_end
	.global __cp_cancel
	.hidden __cp_cancel
	.hidden __cancel
	.global __syscall_cp_asm
	.hidden __syscall_cp_asm
	.text
	.type   __syscall_cp_asm,%function
__syscall_cp_asm:
__cp_begin:
	icm %r2, 15, 0(%r2)
	jne __cp_cancel

	stg %r7, 56(%r15)
	lgr %r1, %r3
	lgr %r2, %r4
	lgr %r3, %r5
	lgr %r4, %r6
	lg  %r5, 160(%r15)
	lg  %r6, 168(%r15)
	lg  %r7, 176(%r15)
	svc 0

__cp_end:
	lg  %r7, 56(%r15)
	br  %r14

__cp_cancel:
	jg  __cancel
