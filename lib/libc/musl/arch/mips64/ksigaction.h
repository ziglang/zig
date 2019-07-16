#include <features.h>

struct k_sigaction {
	unsigned flags;
	void (*handler)(int);
	unsigned long mask[2];
	void (*restorer)();
};

hidden void __restore(), __restore_rt();
