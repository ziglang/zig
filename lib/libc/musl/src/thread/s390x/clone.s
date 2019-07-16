.text
.global __clone
.hidden __clone
.type __clone, %function
__clone:
	# int clone(
	#    fn,      a = r2
	#    stack,   b = r3
	#    flags,   c = r4
	#    arg,     d = r5
	#    ptid,    e = r6
	#    tls,     f = *(r15+160)
	#    ctid)    g = *(r15+168)
	#
	# pseudo C code:
	# tid = syscall(SYS_clone,b,c,e,g,f);
	# if (!tid) syscall(SYS_exit, a(d));
	# return tid;

	# create initial stack frame for new thread
	nill %r3, 0xfff8
	aghi %r3, -160
	lghi %r0, 0
	stg  %r0, 0(%r3)

	# save fn and arg to child stack
	stg  %r2,  8(%r3)
	stg  %r5, 16(%r3)

	# shuffle args into correct registers and call SYS_clone
	lgr  %r2, %r3
	lgr  %r3, %r4
	lgr  %r4, %r6
	lg   %r5, 168(%r15)
	lg   %r6, 160(%r15)
	svc  120

	# if error or if we're the parent, return
	ltgr %r2, %r2
	bnzr %r14

	# we're the child. call fn(arg)
	lg   %r1,  8(%r15)
	lg   %r2, 16(%r15)
	basr %r14, %r1

	# call SYS_exit. exit code is already in r2 from fn return value
	svc  1
