#include <wchar.h>
#include <time.h>
#include <locale.h>
#include "locale_impl.h"
#include "time_impl.h"

size_t __wcsftime_l(wchar_t *restrict s, size_t n, const wchar_t *restrict f, const struct tm *restrict tm, locale_t loc)
{
	size_t l, k;
	char buf[100];
	wchar_t wbuf[100];
	wchar_t *p;
	const char *t_mb;
	const wchar_t *t;
	int pad, plus;
	unsigned long width;
	for (l=0; l<n; f++) {
		if (!*f) {
			s[l] = 0;
			return l;
		}
		if (*f != '%') {
			s[l++] = *f;
			continue;
		}
		f++;
		pad = 0;
		if (*f == '-' || *f == '_' || *f == '0') pad = *f++;
		if ((plus = (*f == '+'))) f++;
		width = wcstoul(f, &p, 10);
		if (*p == 'C' || *p == 'F' || *p == 'G' || *p == 'Y') {
			if (!width && p!=f) width = 1;
		} else {
			width = 0;
		}
		f = p;
		if (*f == 'E' || *f == 'O') f++;
		t_mb = __strftime_fmt_1(&buf, &k, *f, tm, loc, pad);
		if (!t_mb) break;
		k = mbstowcs(wbuf, t_mb, sizeof wbuf / sizeof *wbuf);
		if (k == (size_t)-1) return 0;
		t = wbuf;
		if (width) {
			for (; *t=='+' || *t=='-' || (*t=='0'&&t[1]); t++, k--);
			width--;
			if (plus && tm->tm_year >= 10000-1900)
				s[l++] = '+';
			else if (tm->tm_year < -1900)
				s[l++] = '-';
			else
				width++;
			for (; width > k && l < n; width--)
				s[l++] = '0';
		}
		if (k >= n-l) k = n-l;
		wmemcpy(s+l, t, k);
		l += k;
	}
	if (n) {
		if (l==n) l=n-1;
		s[l] = 0;
	}
	return 0;
}

size_t wcsftime(wchar_t *restrict wcs, size_t n, const wchar_t *restrict f, const struct tm *restrict tm)
{
	return __wcsftime_l(wcs, n, f, tm, CURRENT_LOCALE);
}

weak_alias(__wcsftime_l, wcsftime_l);
