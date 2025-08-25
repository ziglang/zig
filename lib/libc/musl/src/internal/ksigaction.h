#include <features.h>

/* This is the structure used for the rt_sigaction syscall on most archs,
 * but it can be overridden by a file with the same name in the top-level
 * arch dir for a given arch, if necessary. */
struct k_sigaction {
	void (*handler)(int);
	unsigned long flags;
#ifdef SA_RESTORER
	void (*restorer)(void);
#endif
	unsigned mask[2];
#ifndef SA_RESTORER
	void *unused;
#endif
};

hidden void __restore(), __restore_rt();
