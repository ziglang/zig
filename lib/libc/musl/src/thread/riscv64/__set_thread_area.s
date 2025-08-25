.global __set_thread_area
.type   __set_thread_area, %function
__set_thread_area:
	mv tp, a0
	li a0, 0
	ret
