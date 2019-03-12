#include <features.h>

struct k_sigaction {
	unsigned flags;
	void (*handler)(int);
	unsigned long mask[4];
	/* The following field is past the end of the structure the
	 * kernel will read or write, and exists only to avoid having
	 * mips-specific preprocessor conditionals in sigaction.c. */
	void (*restorer)();
};

hidden void __restore(), __restore_rt();
