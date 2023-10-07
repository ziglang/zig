#include "time32.h"
#include <time.h>
#include <string.h>
#include <sys/stat.h>
#include <stddef.h>

struct stat32;

int __fstatat_time32(int fd, const char *restrict path, struct stat32 *restrict st32, int flag)
{
	struct stat st;
	int r = fstatat(fd, path, &st, flag);
	if (!r) memcpy(st32, &st, offsetof(struct stat, st_atim));
	return r;
}
