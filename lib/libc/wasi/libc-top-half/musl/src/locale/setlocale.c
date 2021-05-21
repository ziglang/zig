#include <locale.h>
#include <stdlib.h>
#include <string.h>
#include "locale_impl.h"
#include "libc.h"
#include "lock.h"

static char buf[LC_ALL*(LOCALE_NAME_MAX+1)];

char *setlocale(int cat, const char *name)
{
	const struct __locale_map *lm;

	if ((unsigned)cat > LC_ALL) return 0;

	LOCK(__locale_lock);

	/* For LC_ALL, setlocale is required to return a string which
	 * encodes the current setting for all categories. The format of
	 * this string is unspecified, and only the following code, which
	 * performs both the serialization and deserialization, depends
	 * on the format, so it can easily be changed if needed. */
	if (cat == LC_ALL) {
		int i;
		if (name) {
			struct __locale_struct tmp_locale;
			char part[LOCALE_NAME_MAX+1] = "C.UTF-8";
			const char *p = name;
			for (i=0; i<LC_ALL; i++) {
				const char *z = __strchrnul(p, ';');
				if (z-p <= LOCALE_NAME_MAX) {
					memcpy(part, p, z-p);
					part[z-p] = 0;
					if (*z) p = z+1;
				}
				lm = __get_locale(i, part);
				if (lm == LOC_MAP_FAILED) {
					UNLOCK(__locale_lock);
					return 0;
				}
				tmp_locale.cat[i] = lm;
			}
			libc.global_locale = tmp_locale;
		}
		char *s = buf;
		const char *part;
		int same = 0;
		for (i=0; i<LC_ALL; i++) {
			const struct __locale_map *lm =
				libc.global_locale.cat[i];
			if (lm == libc.global_locale.cat[0]) same++;
			part = lm ? lm->name : "C";
			size_t l = strlen(part);
			memcpy(s, part, l);
			s[l] = ';';
			s += l+1;
		}
		*--s = 0;
		UNLOCK(__locale_lock);
		return same==LC_ALL ? (char *)part : buf;
	}

	if (name) {
		lm = __get_locale(cat, name);
		if (lm == LOC_MAP_FAILED) {
			UNLOCK(__locale_lock);
			return 0;
		}
		libc.global_locale.cat[cat] = lm;
	} else {
		lm = libc.global_locale.cat[cat];
	}
	char *ret = lm ? (char *)lm->name : "C";

	UNLOCK(__locale_lock);

	return ret;
}
