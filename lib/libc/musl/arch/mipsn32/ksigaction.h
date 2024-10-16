#include <features.h>

struct k_sigaction {
	unsigned flags;
	void (*handler)(int);
	unsigned long mask[4];
	void *unused;
};

hidden void __restore(), __restore_rt();
