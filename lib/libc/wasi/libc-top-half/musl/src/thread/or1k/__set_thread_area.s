.global __set_thread_area
.hidden __set_thread_area
.type   __set_thread_area,@function
__set_thread_area:
	l.ori	r10, r3, 0
	l.jr	r9
	 l.ori	r11, r0, 0
