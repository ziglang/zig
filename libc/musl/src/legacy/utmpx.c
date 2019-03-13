#define _GNU_SOURCE
#include <utmpx.h>
#include <stddef.h>
#include <errno.h>

void endutxent(void)
{
}

void setutxent(void)
{
}

struct utmpx *getutxent(void)
{
	return NULL;
}

struct utmpx *getutxid(const struct utmpx *ut)
{
	return NULL;
}

struct utmpx *getutxline(const struct utmpx *ut)
{
	return NULL;
}

struct utmpx *pututxline(const struct utmpx *ut)
{
	return NULL;
}

void updwtmpx(const char *f, const struct utmpx *u)
{
}

static int __utmpxname(const char *f)
{
	errno = ENOTSUP;
	return -1;
}

weak_alias(endutxent, endutent);
weak_alias(setutxent, setutent);
weak_alias(getutxent, getutent);
weak_alias(getutxid, getutid);
weak_alias(getutxline, getutline);
weak_alias(pututxline, pututline);
weak_alias(updwtmpx, updwtmp);
weak_alias(__utmpxname, utmpname);
weak_alias(__utmpxname, utmpxname);
