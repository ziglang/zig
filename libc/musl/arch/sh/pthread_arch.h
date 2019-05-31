static inline struct pthread *__pthread_self()
{
	char *self;
	__asm__ ("stc gbr,%0" : "=r" (self) );
	return (struct pthread *) (self - sizeof(struct pthread));
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 8
#define TP_ADJ(p) ((char *)(p) + sizeof(struct pthread))

#define MC_PC sc_pc

#ifdef __FDPIC__
#define MC_GOT sc_regs[12]
#define CANCEL_GOT (*(uintptr_t *)((char *)__syscall_cp_asm+sizeof(uintptr_t)))
#endif
