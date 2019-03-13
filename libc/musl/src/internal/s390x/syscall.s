.global __syscall
.hidden __syscall
.type   __syscall, %function
__syscall:
	stg %r7, 56(%r15)
	lgr %r1, %r2
	lgr %r2, %r3
	lgr %r3, %r4
	lgr %r4, %r5
	lgr %r5, %r6
	lg  %r6, 160(%r15)
	lg  %r7, 168(%r15)
	svc 0
	lg  %r7, 56(%r15)
	br  %r14
