.global __set_thread_area
.hidden __set_thread_area
.type   __set_thread_area,@function
__set_thread_area:
	move $tp, $a0
	move $a0, $zero
	jr   $ra
