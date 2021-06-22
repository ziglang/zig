.text
.global __set_thread_area
.hidden __set_thread_area
.type   __set_thread_area, %function
__set_thread_area:
	mr 13, 3
	li  3, 0
	blr

