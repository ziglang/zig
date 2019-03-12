static inline struct pthread *__pthread_self()
{
	struct pthread *self;
	__asm__ ("movl %%gs:0,%0" : "=r" (self) );
	return self;
}

#define TP_ADJ(p) (p)

#define MC_PC gregs[REG_EIP]
