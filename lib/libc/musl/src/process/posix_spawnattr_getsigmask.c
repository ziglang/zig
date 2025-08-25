#include <spawn.h>

int posix_spawnattr_getsigmask(const posix_spawnattr_t *restrict attr, sigset_t *restrict mask)
{
	*mask = attr->__mask;
	return 0;
}
