static inline uintptr_t __get_tp()
{
	uintptr_t tp;
	__asm__ ("mrs %0,tpidr_el0" : "=r"(tp));
	return tp;
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 16

#define MC_PC pc
