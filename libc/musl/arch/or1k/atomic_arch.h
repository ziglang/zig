#define a_cas a_cas
static inline int a_cas(volatile int *p, int t, int s)
{
	__asm__("1:	l.lwa %0, %1\n"
		"	l.sfeq %0, %2\n"
		"	l.bnf 1f\n"
		"	 l.nop\n"
		"	l.swa %1, %3\n"
		"	l.bnf 1b\n"
		"	 l.nop\n"
		"1:	\n"
		: "=&r"(t), "+m"(*p) : "r"(t), "r"(s) : "cc", "memory" );
        return t;
}
