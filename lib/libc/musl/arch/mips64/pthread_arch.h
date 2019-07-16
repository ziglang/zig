static inline struct pthread *__pthread_self()
{
#if __mips_isa_rev < 2
	register char *tp __asm__("$3");
	__asm__ (".word 0x7c03e83b" : "=r" (tp) );
#else
	char *tp;
	__asm__ ("rdhwr %0, $29" : "=r" (tp) );
#endif
	return (pthread_t)(tp - 0x7000 - sizeof(struct pthread));
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 0
#define TP_ADJ(p) ((char *)(p) + sizeof(struct pthread) + 0x7000)

#define DTP_OFFSET 0x8000

#define MC_PC pc
