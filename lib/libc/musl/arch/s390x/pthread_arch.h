static inline uintptr_t __get_tp()
{
	uintptr_t tp;
	__asm__ (
		"ear  %0, %%a0\n"
		"sllg %0, %0, 32\n"
		"ear  %0, %%a1\n"
		: "=r"(tp));
	return tp;
}

#define MC_PC psw.addr
