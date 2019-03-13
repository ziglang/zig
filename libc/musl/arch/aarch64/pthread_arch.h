static inline struct pthread *__pthread_self()
{
	char *self;
	__asm__ ("mrs %0,tpidr_el0" : "=r"(self));
	return (void*)(self - sizeof(struct pthread));
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 16
#define TP_ADJ(p) ((char *)(p) + sizeof(struct pthread))

#define MC_PC pc
