#include <unistd.h>

pid_t setpgrp(void)
{
	return setpgid(0, 0);
}
