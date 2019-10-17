static inline struct pthread *__pthread_self()
{
	char *tp;
	__asm__ __volatile__("mv %0, tp" : "=r"(tp));
	return (void *)(tp - sizeof(struct pthread));
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 0
#define TP_ADJ(p) ((char *)p + sizeof(struct pthread))

#define DTP_OFFSET 0x800

#define MC_PC __gregs[0]
