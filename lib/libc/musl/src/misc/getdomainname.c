#define _GNU_SOURCE
#include <unistd.h>
#include <sys/utsname.h>
#include <string.h>
#include <errno.h>

int getdomainname(char *name, size_t len)
{
	struct utsname temp;
	uname(&temp);
	if (!len || strlen(temp.domainname) >= len) {
		errno = EINVAL;
		return -1;
	}
	strcpy(name, temp.domainname);
	return 0;
}
