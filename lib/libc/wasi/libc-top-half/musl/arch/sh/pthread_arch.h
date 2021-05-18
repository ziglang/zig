static inline uintptr_t __get_tp()
{
	uintptr_t tp;
	__asm__ ("stc gbr,%0" : "=r" (tp) );
	return tp;
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 8

#define MC_PC pc

#ifdef __FDPIC__
#define MC_GOT gregs[12]
#define CANCEL_GOT (*(uintptr_t *)((char *)__syscall_cp_asm+sizeof(uintptr_t)))
#endif
