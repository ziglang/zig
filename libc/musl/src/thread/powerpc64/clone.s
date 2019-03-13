.text
.global __clone
.hidden __clone
.type __clone, %function
__clone:
	# int clone(fn, stack, flags, arg, ptid, tls, ctid)
	#            a  b       c     d     e    f    g
	#            3  4       5     6     7    8    9
	# pseudo C code:
	# tid = syscall(SYS_clone,c,b,e,f,g);
	# if (!tid) syscall(SYS_exit, a(d));
	# return tid;

	# create initial stack frame for new thread
	clrrdi 4, 4, 4
	li     0, 0
	stdu   0,-32(4)

	# save fn and arg to child stack
	std    3,  8(4)
	std    6, 16(4)

	# shuffle args into correct registers and call SYS_clone
	mr    3, 5
	#mr   4, 4
	mr    5, 7
	mr    6, 8
	mr    7, 9
	li    0, 120  # SYS_clone = 120
	sc

	# if error, negate return (errno)
	bns+  1f
	neg   3, 3

1:	# if we're the parent, return
	cmpwi cr7, 3, 0
	bnelr cr7

	# we're the child. call fn(arg)
	ld     3, 16(1)
	ld    12,  8(1)
	mtctr 12
	bctrl

	# call SYS_exit. exit code is already in r3 from fn return value
	li    0, 1    # SYS_exit = 1
	sc
