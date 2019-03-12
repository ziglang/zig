#define _GNU_SOURCE
#include <pwd.h>
#include <stdio.h>
#include <unistd.h>

char *cuserid(char *buf)
{
	struct passwd pw, *ppw;
	long pwb[256];
	if (getpwuid_r(geteuid(), &pw, (void *)pwb, sizeof pwb, &ppw))
		return 0;
	snprintf(buf, L_cuserid, "%s", pw.pw_name);
	return buf;
}
