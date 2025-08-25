.global sqrt
.type sqrt,@function
sqrt:	sqrtsd %xmm0, %xmm0
	ret
