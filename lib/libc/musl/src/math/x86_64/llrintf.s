.global llrintf
.type llrintf,@function
llrintf:
	cvtss2si %xmm0,%rax
	ret
