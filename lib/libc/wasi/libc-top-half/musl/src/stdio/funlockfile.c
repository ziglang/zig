#include "stdio_impl.h"
#include "pthread_impl.h"

void funlockfile(FILE *f)
{
	if (f->lockcount == 1) {
		__unlist_locked_file(f);
		f->lockcount = 0;
		__unlockfile(f);
	} else {
		f->lockcount--;
	}
}
