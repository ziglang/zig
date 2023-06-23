#include "time32.h"
#include <time.h>
#include <string.h>
#include <sys/stat.h>
#include <stddef.h>

struct stat32;

int __lstat_time32(const char *restrict path, struct stat32 *restrict st32)
{
	struct stat st;
	int r = lstat(path, &st);
	if (!r) memcpy(st32, &st, offsetof(struct stat, st_atim));
	return r;
}
