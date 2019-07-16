#include <spawn.h>

int posix_spawnattr_setpgroup(posix_spawnattr_t *attr, pid_t pgrp)
{
	attr->__pgrp = pgrp;
	return 0;
}
