.global __set_thread_area
.type   __set_thread_area,@function
__set_thread_area:
	{ ugp = r0
	  r0 = #0
	  jumpr r31 }
.size __set_thread_area, .-__set_thread_area
