#include <stdio.h>
#include <string.h>
#include <errno.h>
#include "stdio_impl.h"

void perror(const char *msg)
{
	FILE *f = stderr;
	char *errstr = strerror(errno);

	FLOCK(f);

	/* Save stderr's orientation and encoding rule, since perror is not
	 * permitted to change them. */
	void *old_locale = f->locale;
	int old_mode = f->mode;
	
	if (msg && *msg) {
		fwrite(msg, strlen(msg), 1, f);
		fputc(':', f);
		fputc(' ', f);
	}
	fwrite(errstr, strlen(errstr), 1, f);
	fputc('\n', f);

	f->mode = old_mode;
	f->locale = old_locale;

	FUNLOCK(f);
}
