#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void dummy(char *old, char *new) {}
weak_alias(dummy, __env_rm_add);

int __putenv(char *s, size_t l, char *r)
{
#ifdef __wasilibc_unmodified_upstream // Lazy environment variable init.
#else
// This specialized header is included within the function body to arranges for
// the environment variables to be lazily initialized. It redefined `__environ`,
// so don't remove or reorder it with respect to other code.
#include "wasi/libc-environ-compat.h"
#endif
	size_t i=0;
	if (__environ) {
		for (char **e = __environ; *e; e++, i++)
			if (!strncmp(s, *e, l+1)) {
				char *tmp = *e;
				*e = s;
				__env_rm_add(tmp, r);
				return 0;
			}
	}
	static char **oldenv;
	char **newenv;
	if (__environ == oldenv) {
		newenv = realloc(oldenv, sizeof *newenv * (i+2));
		if (!newenv) goto oom;
	} else {
		newenv = malloc(sizeof *newenv * (i+2));
		if (!newenv) goto oom;
		if (i) memcpy(newenv, __environ, sizeof *newenv * i);
		free(oldenv);
	}
	newenv[i] = s;
	newenv[i+1] = 0;
	__environ = oldenv = newenv;
	if (r) __env_rm_add(0, r);
	return 0;
oom:
	free(r);
	return -1;
}

int putenv(char *s)
{
	size_t l = __strchrnul(s, '=') - s;
	if (!l || !s[l]) return unsetenv(s);
	return __putenv(s, l, 0);
}
