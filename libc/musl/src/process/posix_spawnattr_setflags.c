#include <spawn.h>
#include <errno.h>

int posix_spawnattr_setflags(posix_spawnattr_t *attr, short flags)
{
	const unsigned all_flags =
		POSIX_SPAWN_RESETIDS |
		POSIX_SPAWN_SETPGROUP |
		POSIX_SPAWN_SETSIGDEF |
		POSIX_SPAWN_SETSIGMASK |
		POSIX_SPAWN_SETSCHEDPARAM |
		POSIX_SPAWN_SETSCHEDULER |
		POSIX_SPAWN_USEVFORK |
		POSIX_SPAWN_SETSID;
	if (flags & ~all_flags) return EINVAL;
	attr->__flags = flags;
	return 0;
}
