#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <ctype.h>
#include <wchar.h>
#include <wctype.h>
#include <limits.h>
#include <string.h>

#include "stdio_impl.h"
#include "shgetc.h"
#include "intscan.h"
#include "floatscan.h"

#define SIZE_hh -2
#define SIZE_h  -1
#define SIZE_def 0
#define SIZE_l   1
#define SIZE_L   2
#define SIZE_ll  3

static void store_int(void *dest, int size, unsigned long long i)
{
	if (!dest) return;
	switch (size) {
	case SIZE_hh:
		*(char *)dest = i;
		break;
	case SIZE_h:
		*(short *)dest = i;
		break;
	case SIZE_def:
		*(int *)dest = i;
		break;
	case SIZE_l:
		*(long *)dest = i;
		break;
	case SIZE_ll:
		*(long long *)dest = i;
		break;
	}
}

static void *arg_n(va_list ap, unsigned int n)
{
	void *p;
	unsigned int i;
	va_list ap2;
	va_copy(ap2, ap);
	for (i=n; i>1; i--) va_arg(ap2, void *);
	p = va_arg(ap2, void *);
	va_end(ap2);
	return p;
}

static int in_set(const wchar_t *set, int c)
{
	int j;
	const wchar_t *p = set;
	if (*p == '-') {
		if (c=='-') return 1;
		p++;
	} else if (*p == ']') {
		if (c==']') return 1;
		p++;
	}
	for (; *p && *p != ']'; p++) {
		if (*p=='-' && p[1] && p[1] != ']')
			for (j=p++[-1]; j<*p; j++)
				if (c==j) return 1;
		if (c==*p) return 1;
	}
	return 0;
}

#if 1
#undef getwc
#define getwc(f) \
	((f)->rpos != (f)->rend && *(f)->rpos < 128 ? *(f)->rpos++ : (getwc)(f))

#undef ungetwc
#define ungetwc(c,f) \
	((f)->rend && (c)<128U ? *--(f)->rpos : ungetwc((c),(f)))
#endif

int vfwscanf(FILE *restrict f, const wchar_t *restrict fmt, va_list ap)
{
	int width;
	int size;
	int alloc;
	const wchar_t *p;
	int c, t;
	char *s;
	wchar_t *wcs;
	void *dest=NULL;
	int invert;
	int matches=0;
	off_t pos = 0, cnt;
	static const char size_pfx[][3] = { "hh", "h", "", "l", "L", "ll" };
	char tmp[3*sizeof(int)+10];
	const wchar_t *set;
	size_t i, k;

	FLOCK(f);

	fwide(f, 1);

	for (p=fmt; *p; p++) {

		alloc = 0;

		if (iswspace(*p)) {
			while (iswspace(p[1])) p++;
			while (iswspace((c=getwc(f)))) pos++;
			ungetwc(c, f);
			continue;
		}
		if (*p != '%' || p[1] == '%') {
			if (*p == '%') {
				p++;
				while (iswspace((c=getwc(f)))) pos++;
			} else {
				c = getwc(f);
			}
			if (c!=*p) {
				ungetwc(c, f);
				if (c<0) goto input_fail;
				goto match_fail;
			}
			pos++;
			continue;
		}

		p++;
		if (*p=='*') {
			dest = 0; p++;
		} else if (iswdigit(*p) && p[1]=='$') {
			dest = arg_n(ap, *p-'0'); p+=2;
		} else {
			dest = va_arg(ap, void *);
		}

		for (width=0; iswdigit(*p); p++) {
			width = 10*width + *p - '0';
		}

		if (*p=='m') {
			wcs = 0;
			s = 0;
			alloc = !!dest;
			p++;
		} else {
			alloc = 0;
		}

		size = SIZE_def;
		switch (*p++) {
		case 'h':
			if (*p == 'h') p++, size = SIZE_hh;
			else size = SIZE_h;
			break;
		case 'l':
			if (*p == 'l') p++, size = SIZE_ll;
			else size = SIZE_l;
			break;
		case 'j':
			size = SIZE_ll;
			break;
		case 'z':
		case 't':
			size = SIZE_l;
			break;
		case 'L':
			size = SIZE_L;
			break;
		case 'd': case 'i': case 'o': case 'u': case 'x':
		case 'a': case 'e': case 'f': case 'g':
		case 'A': case 'E': case 'F': case 'G': case 'X':
		case 's': case 'c': case '[':
		case 'S': case 'C':
		case 'p': case 'n':
			p--;
			break;
		default:
			goto fmt_fail;
		}

		t = *p;

		/* Transform S,C -> ls,lc */
		if ((t&0x2f)==3) {
			size = SIZE_l;
			t |= 32;
		}

		if (t != 'n') {
			if (t != '[' && (t|32) != 'c')
				while (iswspace((c=getwc(f)))) pos++;
			else
				c=getwc(f);
			if (c < 0) goto input_fail;
			ungetwc(c, f);
		}

		switch (t) {
		case 'n':
			store_int(dest, size, pos);
			/* do not increment match count, etc! */
			continue;

		case 's':
		case 'c':
		case '[':
			if (t == 'c') {
				if (width<1) width = 1;
				invert = 1;
				set = L"";
			} else if (t == 's') {
				invert = 1;
				static const wchar_t spaces[] = {
					' ', '\t', '\n', '\r', 11, 12,  0x0085,
					0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005,
					0x2006, 0x2008, 0x2009, 0x200a,
					0x2028, 0x2029, 0x205f, 0x3000, 0 };
				set = spaces;
			} else {
				if (*++p == '^') p++, invert = 1;
				else invert = 0;
				set = p;
				if (*p==']') p++;
				while (*p!=']') {
					if (!*p) goto fmt_fail;
					p++;
				}
			}

			s = (size == SIZE_def) ? dest : 0;
			wcs = (size == SIZE_l) ? dest : 0;

			int gotmatch = 0;

			if (width < 1) width = -1;

			i = 0;
			if (alloc) {
				k = t=='c' ? width+1U : 31;
				if (size == SIZE_l) {
					wcs = malloc(k*sizeof(wchar_t));
					if (!wcs) goto alloc_fail;
				} else {
					s = malloc(k);
					if (!s) goto alloc_fail;
				}
			}
			while (width) {
				if ((c=getwc(f))<0) break;
				if (in_set(set, c) == invert)
					break;
				if (wcs) {
					wcs[i++] = c;
					if (alloc && i==k) {
						k += k+1;
						wchar_t *tmp = realloc(wcs, k*sizeof(wchar_t));
						if (!tmp) goto alloc_fail;
						wcs = tmp;
					}
				} else if (size != SIZE_l) {
					int l = wctomb(s?s+i:tmp, c);
					if (l<0) goto input_fail;
					i += l;
					if (alloc && i > k-4) {
						k += k+1;
						char *tmp = realloc(s, k);
						if (!tmp) goto alloc_fail;
						s = tmp;
					}
				}
				pos++;
				width-=(width>0);
				gotmatch=1;
			}
			if (width) {
				ungetwc(c, f);
				if (t == 'c' || !gotmatch) goto match_fail;
			}

			if (alloc) {
				if (size == SIZE_l) *(wchar_t **)dest = wcs;
				else *(char **)dest = s;
			}
			if (t != 'c') {
				if (wcs) wcs[i] = 0;
				if (s) s[i] = 0;
			}
			break;

		case 'd': case 'i': case 'o': case 'u': case 'x':
		case 'a': case 'e': case 'f': case 'g':
		case 'A': case 'E': case 'F': case 'G': case 'X':
		case 'p':
			if (width < 1) width = 0;
			snprintf(tmp, sizeof tmp, "%.*s%.0d%s%c%%lln",
				1+!dest, "%*", width, size_pfx[size+2], t);
			cnt = 0;
			if (fscanf(f, tmp, dest?dest:&cnt, &cnt) == -1)
				goto input_fail;
			else if (!cnt)
				goto match_fail;
			pos += cnt;
			break;
		default:
			goto fmt_fail;
		}

		if (dest) matches++;
	}
	if (0) {
fmt_fail:
alloc_fail:
input_fail:
		if (!matches) matches--;
match_fail:
		if (alloc) {
			free(s);
			free(wcs);
		}
	}
	FUNLOCK(f);
	return matches;
}

weak_alias(vfwscanf,__isoc99_vfwscanf);
