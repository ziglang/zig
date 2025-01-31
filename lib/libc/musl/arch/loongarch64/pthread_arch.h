static inline uintptr_t __get_tp()
{
	register uintptr_t tp __asm__("tp");
	__asm__ ("" : "=r" (tp) );
	return tp;
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP   0
#define DTP_OFFSET     0
#define MC_PC          __pc
