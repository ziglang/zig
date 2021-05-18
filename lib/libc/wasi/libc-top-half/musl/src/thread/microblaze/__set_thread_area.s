.global __set_thread_area
.hidden __set_thread_area
.type   __set_thread_area,@function
__set_thread_area:
	ori      r21, r5, 0
	rtsd     r15, 8
	ori      r3, r0, 0
