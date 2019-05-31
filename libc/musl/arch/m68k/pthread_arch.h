static inline struct pthread *__pthread_self()
{
	uintptr_t tp = __syscall(SYS_get_thread_area);
	return (pthread_t)(tp - 0x7000 - sizeof(struct pthread));
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 0
#define TP_ADJ(p) ((char *)(p) + sizeof(struct pthread) + 0x7000)

#define DTP_OFFSET 0x8000

#define MC_PC gregs[R_PC]
