#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>

static void dummy(char *old, char *new) {}
weak_alias(dummy, __env_rm_add);

int unsetenv(const char *name)
{
	size_t l = __strchrnul(name, '=') - name;
	if (!l || name[l]) {
		errno = EINVAL;
		return -1;
	}
#ifdef __wasilibc_unmodified_upstream // Lazy environment variable init.
#else
// This specialized header is included within the function body to arranges for
// the environment variables to be lazily initialized. It redefined `__environ`,
// so don't remove or reorder it with respect to other code.
#include "wasi/libc-environ-compat.h"
#endif
	if (__environ) {
		char **e = __environ, **eo = e;
		for (; *e; e++)
			if (!strncmp(name, *e, l) && l[*e] == '=')
				__env_rm_add(*e, 0);
			else if (eo != e)
				*eo++ = *e;
			else
				eo++;
		if (eo != e) *eo = 0;
	}
	return 0;
}
