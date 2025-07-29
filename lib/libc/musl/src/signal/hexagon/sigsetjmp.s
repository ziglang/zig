.global sigsetjmp
.global __sigsetjmp
.type sigsetjmp,@function
.type __sigsetjmp,@function
.balign 4
sigsetjmp:
__sigsetjmp:
	// if savemask is 0 sigsetjmp behaves like setjmp
	{
		p0 = cmp.eq(r1, #0)
		if (p0.new) jump:t ##setjmp
	}
	{
		memw(r0+#64+4+8) = r16  // save r16 in __ss[2]
		memw(r0+#64)   = r31  // save linkregister in __fl
		r16 = r0
	}
		call ##setjmp
	{
		r1 = r0;
		r0  = r16             // restore r0
		r31 = memw(r16+#64)   // restore linkregister
		r16 = memw(r16+#64+4+8) // restore r16 from __ss[2]
	}
.hidden __sigsetjmp_tail
	jump ##__sigsetjmp_tail

.size	sigsetjmp, .-sigsetjmp
