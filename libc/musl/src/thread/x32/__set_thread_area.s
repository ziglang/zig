/* Copyright 2011-2012 Nicholas J. Kain, licensed under standard MIT license */
.text
.global __set_thread_area
.hidden __set_thread_area
.type __set_thread_area,@function
__set_thread_area:
	mov %edi,%esi           /* shift for syscall */
	movl $0x1002,%edi       /* SET_FS register */
	movl $0x4000009e,%eax          /* set fs segment to */
	syscall                 /* arch_prctl(SET_FS, arg)*/
	ret
