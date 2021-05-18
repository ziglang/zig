static inline uintptr_t __get_tp()
{
#ifdef __clang__
	uintptr_t tp;
	__asm__ ("l.ori %0, r10, 0" : "=r" (tp) );
#else
	register uintptr_t tp __asm__("r10");
	__asm__ ("" : "=r" (tp) );
#endif
	return tp;
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 0

#define MC_PC regs.pc
