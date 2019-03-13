.text
.global __set_thread_area
.hidden __set_thread_area
.type   __set_thread_area, %function
__set_thread_area:
	sar  %a1, %r2
	srlg %r2, %r2, 32
	sar  %a0, %r2
	lghi %r2, 0
	br   %r14
