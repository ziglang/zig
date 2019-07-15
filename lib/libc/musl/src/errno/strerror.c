#include <errno.h>
#include <string.h>
#include "locale_impl.h"

#define E(a,b) ((unsigned char)a),
static const unsigned char errid[] = {
#include "__strerror.h"
};

#undef E
#define E(a,b) b "\0"
static const char errmsg[] =
#include "__strerror.h"
;

char *__strerror_l(int e, locale_t loc)
{
	const char *s;
	int i;
	/* mips has one error code outside of the 8-bit range due to a
	 * historical typo, so we just remap it. */
	if (EDQUOT==1133) {
		if (e==109) e=-1;
		else if (e==EDQUOT) e=109;
	}
	for (i=0; errid[i] && errid[i] != e; i++);
	for (s=errmsg; i; s++, i--) for (; *s; s++);
	return (char *)LCTRANS(s, LC_MESSAGES, loc);
}

char *strerror(int e)
{
	return __strerror_l(e, CURRENT_LOCALE);
}

weak_alias(__strerror_l, strerror_l);
