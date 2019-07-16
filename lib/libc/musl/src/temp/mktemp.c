#define _GNU_SOURCE
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/stat.h>

char *mktemp(char *template)
{
	size_t l = strlen(template);
	int retries = 100;
	struct stat st;

	if (l < 6 || memcmp(template+l-6, "XXXXXX", 6)) {
		errno = EINVAL;
		*template = 0;
		return template;
	}

	do {
		__randname(template+l-6);
		if (stat(template, &st)) {
			if (errno != ENOENT) *template = 0;
			return template;
		}
	} while (--retries);

	*template = 0;
	errno = EEXIST;
	return template;
}
