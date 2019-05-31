static inline struct pthread *__pthread_self()
{
	struct pthread *self;
	__asm__ ("mov %%fs:0,%0" : "=r" (self) );
	return self;
}

#define TP_ADJ(p) (p)

#define MC_PC gregs[REG_RIP]

#define CANARY canary2

#define tls_mod_off_t unsigned long long
