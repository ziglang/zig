	.global __syscall
	.hidden __syscall
	.type   __syscall,@function
__syscall:
	mr      0, 3                  # Save the system call number
	mr      3, 4                  # Shift the arguments: arg1
	mr      4, 5                  # arg2
	mr      5, 6                  # arg3
	mr      6, 7                  # arg4
	mr      7, 8                  # arg5
	mr      8, 9                  # arg6
	sc
	bnslr+       # return if not summary overflow
	neg     3, 3 # otherwise error: return negated value.
	blr
	.end    __syscall
	.size   __syscall, .-__syscall
