static inline uintptr_t __get_tp()
{
	uintptr_t tp;
	__asm__ ("ori %0, r21, 0" : "=r" (tp) );
	return tp;
}

#define MC_PC regs.pc
