#include <stdlib.h>
#include <string.h>
#include "locale_impl.h"
#include "libc.h"

#define malloc __libc_malloc
#define calloc undef
#define realloc undef
#define free undef

locale_t __duplocale(locale_t old)
{
	locale_t new = malloc(sizeof *new);
	if (!new) return 0;
	if (old == LC_GLOBAL_LOCALE) old = &libc.global_locale;
	*new = *old;
	return new;
}

weak_alias(__duplocale, duplocale);
