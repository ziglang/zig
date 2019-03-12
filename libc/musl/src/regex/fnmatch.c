/*
 * An implementation of what I call the "Sea of Stars" algorithm for
 * POSIX fnmatch(). The basic idea is that we factor the pattern into
 * a head component (which we match first and can reject without ever
 * measuring the length of the string), an optional tail component
 * (which only exists if the pattern contains at least one star), and
 * an optional "sea of stars", a set of star-separated components
 * between the head and tail. After the head and tail matches have
 * been removed from the input string, the components in the "sea of
 * stars" are matched sequentially by searching for their first
 * occurrence past the end of the previous match.
 *
 * - Rich Felker, April 2012
 */

#include <string.h>
#include <fnmatch.h>
#include <stdlib.h>
#include <wchar.h>
#include <wctype.h>
#include "locale_impl.h"

#define END 0
#define UNMATCHABLE -2
#define BRACKET -3
#define QUESTION -4
#define STAR -5

static int str_next(const char *str, size_t n, size_t *step)
{
	if (!n) {
		*step = 0;
		return 0;
	}
	if (str[0] >= 128U) {
		wchar_t wc;
		int k = mbtowc(&wc, str, n);
		if (k<0) {
			*step = 1;
			return -1;
		}
		*step = k;
		return wc;
	}
	*step = 1;
	return str[0];
}

static int pat_next(const char *pat, size_t m, size_t *step, int flags)
{
	int esc = 0;
	if (!m || !*pat) {
		*step = 0;
		return END;
	}
	*step = 1;
	if (pat[0]=='\\' && pat[1] && !(flags & FNM_NOESCAPE)) {
		*step = 2;
		pat++;
		esc = 1;
		goto escaped;
	}
	if (pat[0]=='[') {
		size_t k = 1;
		if (k<m) if (pat[k] == '^' || pat[k] == '!') k++;
		if (k<m) if (pat[k] == ']') k++;
		for (; k<m && pat[k] && pat[k]!=']'; k++) {
			if (k+1<m && pat[k+1] && pat[k]=='[' && (pat[k+1]==':' || pat[k+1]=='.' || pat[k+1]=='=')) {
				int z = pat[k+1];
				k+=2;
				if (k<m && pat[k]) k++;
				while (k<m && pat[k] && (pat[k-1]!=z || pat[k]!=']')) k++;
				if (k==m || !pat[k]) break;
			}
		}
		if (k==m || !pat[k]) {
			*step = 1;
			return '[';
		}
		*step = k+1;
		return BRACKET;
	}
	if (pat[0] == '*')
		return STAR;
	if (pat[0] == '?')
		return QUESTION;
escaped:
	if (pat[0] >= 128U) {
		wchar_t wc;
		int k = mbtowc(&wc, pat, m);
		if (k<0) {
			*step = 0;
			return UNMATCHABLE;
		}
		*step = k + esc;
		return wc;
	}
	return pat[0];
}

static int casefold(int k)
{
	int c = towupper(k);
	return c == k ? towlower(k) : c;
}

static int match_bracket(const char *p, int k, int kfold)
{
	wchar_t wc;
	int inv = 0;
	p++;
	if (*p=='^' || *p=='!') {
		inv = 1;
		p++;
	}
	if (*p==']') {
		if (k==']') return !inv;
		p++;
	} else if (*p=='-') {
		if (k=='-') return !inv;
		p++;
	}
	wc = p[-1];
	for (; *p != ']'; p++) {
		if (p[0]=='-' && p[1]!=']') {
			wchar_t wc2;
			int l = mbtowc(&wc2, p+1, 4);
			if (l < 0) return 0;
			if (wc <= wc2)
				if ((unsigned)k-wc <= wc2-wc ||
				    (unsigned)kfold-wc <= wc2-wc)
					return !inv;
			p += l-1;
			continue;
		}
		if (p[0]=='[' && (p[1]==':' || p[1]=='.' || p[1]=='=')) {
			const char *p0 = p+2;
			int z = p[1];
			p+=3;
			while (p[-1]!=z || p[0]!=']') p++;
			if (z == ':' && p-1-p0 < 16) {
				char buf[16];
				memcpy(buf, p0, p-1-p0);
				buf[p-1-p0] = 0;
				if (iswctype(k, wctype(buf)) ||
				    iswctype(kfold, wctype(buf)))
					return !inv;
			}
			continue;
		}
		if (*p < 128U) {
			wc = (unsigned char)*p;
		} else {
			int l = mbtowc(&wc, p, 4);
			if (l < 0) return 0;
			p += l-1;
		}
		if (wc==k || wc==kfold) return !inv;
	}
	return inv;
}

static int fnmatch_internal(const char *pat, size_t m, const char *str, size_t n, int flags)
{
	const char *p, *ptail, *endpat;
	const char *s, *stail, *endstr;
	size_t pinc, sinc, tailcnt=0;
	int c, k, kfold;

	if (flags & FNM_PERIOD) {
		if (*str == '.' && *pat != '.')
			return FNM_NOMATCH;
	}
	for (;;) {
		switch ((c = pat_next(pat, m, &pinc, flags))) {
		case UNMATCHABLE:
			return FNM_NOMATCH;
		case STAR:
			pat++;
			m--;
			break;
		default:
			k = str_next(str, n, &sinc);
			if (k <= 0)
				return (c==END) ? 0 : FNM_NOMATCH;
			str += sinc;
			n -= sinc;
			kfold = flags & FNM_CASEFOLD ? casefold(k) : k;
			if (c == BRACKET) {
				if (!match_bracket(pat, k, kfold))
					return FNM_NOMATCH;
			} else if (c != QUESTION && k != c && kfold != c) {
				return FNM_NOMATCH;
			}
			pat+=pinc;
			m-=pinc;
			continue;
		}
		break;
	}

	/* Compute real pat length if it was initially unknown/-1 */
	m = strnlen(pat, m);
	endpat = pat + m;

	/* Find the last * in pat and count chars needed after it */
	for (p=ptail=pat; p<endpat; p+=pinc) {
		switch (pat_next(p, endpat-p, &pinc, flags)) {
		case UNMATCHABLE:
			return FNM_NOMATCH;
		case STAR:
			tailcnt=0;
			ptail = p+1;
			break;
		default:
			tailcnt++;
			break;
		}
	}

	/* Past this point we need not check for UNMATCHABLE in pat,
	 * because all of pat has already been parsed once. */

	/* Compute real str length if it was initially unknown/-1 */
	n = strnlen(str, n);
	endstr = str + n;
	if (n < tailcnt) return FNM_NOMATCH;

	/* Find the final tailcnt chars of str, accounting for UTF-8.
	 * On illegal sequences we may get it wrong, but in that case
	 * we necessarily have a matching failure anyway. */
	for (s=endstr; s>str && tailcnt; tailcnt--) {
		if (s[-1] < 128U || MB_CUR_MAX==1) s--;
		else while ((unsigned char)*--s-0x80U<0x40 && s>str);
	}
	if (tailcnt) return FNM_NOMATCH;
	stail = s;

	/* Check that the pat and str tails match */
	p = ptail;
	for (;;) {
		c = pat_next(p, endpat-p, &pinc, flags);
		p += pinc;
		if ((k = str_next(s, endstr-s, &sinc)) <= 0) {
			if (c != END) return FNM_NOMATCH;
			break;
		}
		s += sinc;
		kfold = flags & FNM_CASEFOLD ? casefold(k) : k;
		if (c == BRACKET) {
			if (!match_bracket(p-pinc, k, kfold))
				return FNM_NOMATCH;
		} else if (c != QUESTION && k != c && kfold != c) {
			return FNM_NOMATCH;
		}
	}

	/* We're all done with the tails now, so throw them out */
	endstr = stail;
	endpat = ptail;

	/* Match pattern components until there are none left */
	while (pat<endpat) {
		p = pat;
		s = str;
		for (;;) {
			c = pat_next(p, endpat-p, &pinc, flags);
			p += pinc;
			/* Encountering * completes/commits a component */
			if (c == STAR) {
				pat = p;
				str = s;
				break;
			}
			k = str_next(s, endstr-s, &sinc);
			if (!k)
				return FNM_NOMATCH;
			kfold = flags & FNM_CASEFOLD ? casefold(k) : k;
			if (c == BRACKET) {
				if (!match_bracket(p-pinc, k, kfold))
					break;
			} else if (c != QUESTION && k != c && kfold != c) {
				break;
			}
			s += sinc;
		}
		if (c == STAR) continue;
		/* If we failed, advance str, by 1 char if it's a valid
		 * char, or past all invalid bytes otherwise. */
		k = str_next(str, endstr-str, &sinc);
		if (k > 0) str += sinc;
		else for (str++; str_next(str, endstr-str, &sinc)<0; str++);
	}

	return 0;
}

int fnmatch(const char *pat, const char *str, int flags)
{
	const char *s, *p;
	size_t inc;
	int c;
	if (flags & FNM_PATHNAME) for (;;) {
		for (s=str; *s && *s!='/'; s++);
		for (p=pat; (c=pat_next(p, -1, &inc, flags))!=END && c!='/'; p+=inc);
		if (c!=*s && (!*s || !(flags & FNM_LEADING_DIR)))
			return FNM_NOMATCH;
		if (fnmatch_internal(pat, p-pat, str, s-str, flags))
			return FNM_NOMATCH;
		if (!c) return 0;
		str = s+1;
		pat = p+inc;
	} else if (flags & FNM_LEADING_DIR) {
		for (s=str; *s; s++) {
			if (*s != '/') continue;
			if (!fnmatch_internal(pat, -1, str, s-str, flags))
				return 0;
		}
	}
	return fnmatch_internal(pat, -1, str, -1, flags);
}
