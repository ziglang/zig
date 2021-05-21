#include <stdlib.h>
#include <string.h>
#include <unistd.h>

char *getenv(const char *name)
{
#ifdef __wasilibc_unmodified_upstream // Lazy environment variable init.
#else
// This specialized header is included within the function body to arranges for
// the environment variables to be lazily initialized. It redefined `__environ`,
// so don't remove or reorder it with respect to other code.
#include "wasi/libc-environ-compat.h"
#endif
	size_t l = __strchrnul(name, '=') - name;
	if (l && !name[l] && __environ)
		for (char **e = __environ; *e; e++)
			if (!strncmp(name, *e, l) && l[*e] == '=')
				return *e + l+1;
	return 0;
}
