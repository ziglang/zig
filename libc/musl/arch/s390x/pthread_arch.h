static inline struct pthread *__pthread_self()
{
	struct pthread *self;
	__asm__ (
		"ear  %0, %%a0\n"
		"sllg %0, %0, 32\n"
		"ear  %0, %%a1\n"
		: "=r"(self));
	return self;
}

#define TP_ADJ(p) (p)

#define MC_PC psw.addr
