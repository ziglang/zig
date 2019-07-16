.global __unmapself
.type   __unmapself,@function
__unmapself:
	l.ori	r11, r0, 215 /* __NR_munmap */
	l.sys	1
	l.ori	r3, r0, 0
	l.ori	r11, r0, 93 /* __NR_exit */
	l.sys	1
