#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>

static const char defshells[] = "/bin/sh\n/bin/csh\n";

static char *line;
static size_t linesize;
static FILE *f;

void endusershell(void)
{
	if (f) fclose(f);
	f = 0;
}

void setusershell(void)
{
	if (!f) f = fopen("/etc/shells", "rbe");
	if (!f) f = fmemopen((void *)defshells, sizeof defshells - 1, "rb");
}

char *getusershell(void)
{
	ssize_t l;
	if (!f) setusershell();
	if (!f) return 0;
	l = getline(&line, &linesize, f);
	if (l <= 0) return 0;
	if (line[l-1]=='\n') line[l-1]=0;
	return line;
}
