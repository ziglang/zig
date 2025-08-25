#include <wchar.h>
#include <locale.h>
#include "locale_impl.h"

/* collate only by code points */
size_t __wcsxfrm_l(wchar_t *restrict dest, const wchar_t *restrict src, size_t n, locale_t loc)
{
	size_t l = wcslen(src);
	if (l < n) {
		wmemcpy(dest, src, l+1);
	} else if (n) {
		wmemcpy(dest, src, n-1);
		dest[n-1] = 0;
	}
	return l;
}

size_t wcsxfrm(wchar_t *restrict dest, const wchar_t *restrict src, size_t n)
{
	return __wcsxfrm_l(dest, src, n, CURRENT_LOCALE);
}

weak_alias(__wcsxfrm_l, wcsxfrm_l);
