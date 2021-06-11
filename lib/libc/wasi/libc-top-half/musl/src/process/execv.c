#include <unistd.h>

extern char **__environ;

int execv(const char *path, char *const argv[])
{
	return execve(path, argv, __environ);
}
