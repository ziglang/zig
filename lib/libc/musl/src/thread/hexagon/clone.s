// __clone(func, stack, flags, arg, ptid, tls, ctid)
//         r0,   r1,    r2,    r3,  r4,   r5,  stack

// tid = syscall(SYS_clone, flags, stack, ptid, ctid, tls)
//               r6,        r0,    r1,    r2,   r3,   r4
// if (tid != 0) return
// func(arg)
// syscall(SYS_exit)

.text
.global __clone
.type   __clone,%function
__clone:
	allocframe(#8)
	// Save pointers for later
	{ r11 = r0
	  r10 = r3 }

	// Set up syscall args - The stack must be 8 byte aligned.
	{ r0 = r2
	  r1 = and(r1, ##0xfffffff8)
	  r2 = r4 }
	{
	  r3 = memw(r30+#8)
	  r4 = r5 }
	r6 = #220			// SYS_clone
	trap0(#1)

	p0 = cmp.eq(r0, #0)
	if (!p0) dealloc_return

	{ r0 = r10
	  callr r11 }

	r6 = #93			// SYS_exit
	trap0(#1)
.size __clone, .-__clone
