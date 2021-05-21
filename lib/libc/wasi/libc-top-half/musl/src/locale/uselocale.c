#include "locale_impl.h"
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
#include "pthread_impl.h"
#endif
#include "libc.h"

locale_t __uselocale(locale_t new)
{
#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	pthread_t self = __pthread_self();
	locale_t old = self->locale;
#else
	locale_t old = libc.current_locale;
	if (!old) old = LC_GLOBAL_LOCALE;
#endif
	locale_t global = &libc.global_locale;

#if defined(__wasilibc_unmodified_upstream) || defined(_REENTRANT)
	if (new) self->locale = new == LC_GLOBAL_LOCALE ? global : new;
#else
	if (new) libc.current_locale = new == LC_GLOBAL_LOCALE ? global : new;
#endif

	return old == global ? LC_GLOBAL_LOCALE : old;
}

weak_alias(__uselocale, uselocale);
