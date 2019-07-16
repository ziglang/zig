.global rintf
.type rintf,@function
rintf:
	flds 4(%esp)
	frndint
	ret
