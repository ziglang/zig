.global llrint
.type llrint,@function
llrint:
	cvtsd2si %xmm0,%rax
	ret
