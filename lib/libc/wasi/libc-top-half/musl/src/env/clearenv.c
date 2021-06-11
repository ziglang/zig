#define _GNU_SOURCE
#include <stdlib.h>
#include <unistd.h>

static void dummy(char *old, char *new) {}
weak_alias(dummy, __env_rm_add);

int clearenv()
{
#ifdef __wasilibc_unmodified_upstream // Lazy environment variable init.
#else
// This specialized header is included within the function body to arranges for
// the environment variables to be lazily initialized. It redefined `__environ`,
// so don't remove or reorder it with respect to other code.
#include "wasi/libc-environ-compat.h"
#endif
	char **e = __environ;
	__environ = 0;
	if (e) while (*e) __env_rm_add(*e++, 0);
	return 0;
}
