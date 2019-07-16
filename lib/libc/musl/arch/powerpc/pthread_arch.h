static inline struct pthread *__pthread_self()
{
	register char *tp __asm__("r2");
	__asm__ ("" : "=r" (tp) );
	return (pthread_t)(tp - 0x7000 - sizeof(struct pthread));
}
                        
#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 0
#define TP_ADJ(p) ((char *)(p) + sizeof(struct pthread) + 0x7000)

#define DTP_OFFSET 0x8000

// the kernel calls the ip "nip", it's the first saved value after the 32
// GPRs.
#define MC_PC gregs[32]

#define CANARY canary_at_end
