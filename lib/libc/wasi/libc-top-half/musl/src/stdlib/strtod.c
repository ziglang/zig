#include <stdlib.h>
#ifdef __wasilibc_unmodified_upstream // Changes to optimize printf/scanf when long double isn't needed
#else
#include "printscan.h"
#define __NEED_locale_t
#include <bits/alltypes.h>
#endif
#include "shgetc.h"
#include "floatscan.h"
#include "stdio_impl.h"

#if defined(__wasilibc_printscan_no_long_double)
static long_double strtox(const char *s, char **p, int prec)
#else
static long double strtox(const char *s, char **p, int prec)
#endif
{
	FILE f;
	sh_fromstring(&f, s);
	shlim(&f, 0);
#if defined(__wasilibc_printscan_no_long_double)
	long_double y = __floatscan(&f, prec, 1);
#else
	long double y = __floatscan(&f, prec, 1);
#endif
	off_t cnt = shcnt(&f);
	if (p) *p = cnt ? (char *)s + cnt : (char *)s;
	return y;
}

float strtof(const char *restrict s, char **restrict p)
{
	return strtox(s, p, 0);
}

double strtod(const char *restrict s, char **restrict p)
{
	return strtox(s, p, 1);
}

long double strtold(const char *restrict s, char **restrict p)
{
#if defined(__wasilibc_printscan_no_long_double)
	long_double_not_supported();
#else
	return strtox(s, p, 2);
#endif
}
