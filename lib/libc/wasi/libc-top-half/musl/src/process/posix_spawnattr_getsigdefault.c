#include <spawn.h>

int posix_spawnattr_getsigdefault(const posix_spawnattr_t *restrict attr, sigset_t *restrict def)
{
	*def = attr->__def;
	return 0;
}
