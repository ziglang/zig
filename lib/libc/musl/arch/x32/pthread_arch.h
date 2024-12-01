static inline uintptr_t __get_tp()
{
	uintptr_t tp;
	__asm__ ("mov %%fs:0,%0" : "=r" (tp) );
	return tp;
}

#define MC_PC gregs[REG_RIP]

#define CANARY_PAD

#define tls_mod_off_t unsigned long long
