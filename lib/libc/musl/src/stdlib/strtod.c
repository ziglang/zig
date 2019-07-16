#include <stdlib.h>
#include "shgetc.h"
#include "floatscan.h"
#include "stdio_impl.h"

static long double strtox(const char *s, char **p, int prec)
{
	FILE f;
	sh_fromstring(&f, s);
	shlim(&f, 0);
	long double y = __floatscan(&f, prec, 1);
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
	return strtox(s, p, 2);
}

weak_alias(strtof, strtof_l);
weak_alias(strtod, strtod_l);
weak_alias(strtold, strtold_l);
weak_alias(strtof, __strtof_l);
weak_alias(strtod, __strtod_l);
weak_alias(strtold, __strtold_l);
