#include <string.h>
#include <locale.h>
#include "locale_impl.h"

int __strcoll_l(const char *l, const char *r, locale_t loc)
{
	return strcmp(l, r);
}

int strcoll(const char *l, const char *r)
{
	return __strcoll_l(l, r, CURRENT_LOCALE);
}

weak_alias(__strcoll_l, strcoll_l);
