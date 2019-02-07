.global __executable_start
.global __wrap_get_executable_start

__wrap_get_executable_start:	
	movabs $__executable_start,%rdx
