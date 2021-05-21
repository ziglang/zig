.global lrintf
.type lrintf,@function
lrintf:
	cvtss2si %xmm0,%rax
	ret
