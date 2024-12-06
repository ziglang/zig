static inline uintptr_t __get_tp()
{
#if __mips_isa_rev < 2
	register uintptr_t tp __asm__("$3");
	__asm__ (".word 0x7c03e83b" : "=r" (tp) );
#else
	uintptr_t tp;
	__asm__ ("rdhwr %0, $29" : "=r" (tp) );
#endif
	return tp;
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 0

#define TP_OFFSET 0x7000
#define DTP_OFFSET 0x8000

#define MC_PC pc
