#define _GNU_SOURCE
#include <grp.h>
#include <limits.h>

int initgroups(const char *user, gid_t gid)
{
	gid_t groups[NGROUPS_MAX];
	int count = NGROUPS_MAX;
	if (getgrouplist(user, gid, groups, &count) < 0) return -1;
	return setgroups(count, groups);
}
