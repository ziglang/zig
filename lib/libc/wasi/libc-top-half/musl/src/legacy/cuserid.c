#define _GNU_SOURCE
#include <pwd.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

char *cuserid(char *buf)
{
	static char usridbuf[L_cuserid];
	struct passwd pw, *ppw;
	long pwb[256];
	if (buf) *buf = 0;
	getpwuid_r(geteuid(), &pw, (void *)pwb, sizeof pwb, &ppw);
	if (!ppw)
		return buf;
	size_t len = strnlen(pw.pw_name, L_cuserid);
	if (len == L_cuserid)
		return buf;
	if (!buf) buf = usridbuf;
	memcpy(buf, pw.pw_name, len+1);
	return buf;
}
