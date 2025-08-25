#include <stdlib.h>
#include <string.h>
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
#include <pthread.h>
#endif
#include "locale_impl.h"
#include "lock.h"

#define malloc __libc_malloc
#define calloc undef
#define realloc undef
#define free undef

static int default_locale_init_done;
static struct __locale_struct default_locale, default_ctype_locale;

int __loc_is_allocated(locale_t loc)
{
	return loc && loc != C_LOCALE && loc != UTF8_LOCALE
		&& loc != &default_locale && loc != &default_ctype_locale;
}

static locale_t do_newlocale(int mask, const char *name, locale_t loc)
{
	struct __locale_struct tmp;

	for (int i=0; i<LC_ALL; i++) {
		tmp.cat[i] = (!(mask & (1<<i)) && loc) ? loc->cat[i] :
			__get_locale(i, (mask & (1<<i)) ? name : "");
		if (tmp.cat[i] == LOC_MAP_FAILED)
			return 0;
	}

	/* For locales with allocated storage, modify in-place. */
	if (__loc_is_allocated(loc)) {
		*loc = tmp;
		return loc;
	}

	/* Otherwise, first see if we can use one of the builtin locales.
	 * This makes the common usage case for newlocale, getting a C locale
	 * with predictable behavior, very fast, and more importantly, fail-safe. */
	if (!memcmp(&tmp, C_LOCALE, sizeof tmp)) return C_LOCALE;
	if (!memcmp(&tmp, UTF8_LOCALE, sizeof tmp)) return UTF8_LOCALE;

	/* And provide builtins for the initial default locale, and a
	 * variant of the C locale honoring the default locale's encoding. */
	if (!default_locale_init_done) {
		for (int i=0; i<LC_ALL; i++)
			default_locale.cat[i] = __get_locale(i, "");
		default_ctype_locale.cat[LC_CTYPE] = default_locale.cat[LC_CTYPE];
		default_locale_init_done = 1;
	}
	if (!memcmp(&tmp, &default_locale, sizeof tmp)) return &default_locale;
	if (!memcmp(&tmp, &default_ctype_locale, sizeof tmp))
		return &default_ctype_locale;

	/* If no builtin locale matched, attempt to allocate and copy. */
	if ((loc = malloc(sizeof *loc))) *loc = tmp;

	return loc;
}

locale_t __newlocale(int mask, const char *name, locale_t loc)
{
	LOCK(__locale_lock);
	loc = do_newlocale(mask, name, loc);
	UNLOCK(__locale_lock);
	return loc;
}

weak_alias(__newlocale, newlocale);
