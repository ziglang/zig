static inline uintptr_t __get_tp()
{
	uintptr_t tp;
	__asm__ ("movl %%gs:0,%0" : "=r" (tp) );
	return tp;
}

#define MC_PC gregs[REG_EIP]
