#define _GNU_SOURCE
#include <stdlib.h>
#include <locale.h>

float strtof_l(const char *restrict s, char **restrict p, locale_t l)
{
	return strtof(s, p);
}

double strtod_l(const char *restrict s, char **restrict p, locale_t l)
{
	return strtod(s, p);
}

long double strtold_l(const char *restrict s, char **restrict p, locale_t l)
{
	return strtold(s, p);
}

weak_alias(strtof_l, __strtof_l);
weak_alias(strtod_l, __strtod_l);
weak_alias(strtold_l, __strtold_l);
