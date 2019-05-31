/* or1k use variant I, but with the twist that tp points to the end of TCB */
static inline struct pthread *__pthread_self()
{
#ifdef __clang__
	char *tp;
	__asm__ ("l.ori %0, r10, 0" : "=r" (tp) );
#else
	register char *tp __asm__("r10");
	__asm__ ("" : "=r" (tp) );
#endif
	return (struct pthread *) (tp - sizeof(struct pthread));
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 0
#define TP_ADJ(p) ((char *)(p) + sizeof(struct pthread))

#define MC_PC regs.pc
