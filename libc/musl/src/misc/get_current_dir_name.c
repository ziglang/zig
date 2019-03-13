#define _GNU_SOURCE
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>
#include <sys/stat.h>

char *get_current_dir_name(void) {
	struct stat a, b;
	char *res = getenv("PWD");
	if (res && *res && !stat(res, &a) && !stat(".", &b)
	    && (a.st_dev == b.st_dev) && (a.st_ino == b.st_ino))
		return strdup(res);
	return getcwd(0, 0);
}
