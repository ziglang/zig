#include "stdio_impl.h"
#include <errno.h>
#include <ctype.h>
#include <limits.h>
#include <string.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdlib.h>
#include <wchar.h>
#include <inttypes.h>

/* Convenient bit representation for modifier flags, which all fall
 * within 31 codepoints of the space character. */

#define ALT_FORM   (1U<<'#'-' ')
#define ZERO_PAD   (1U<<'0'-' ')
#define LEFT_ADJ   (1U<<'-'-' ')
#define PAD_POS    (1U<<' '-' ')
#define MARK_POS   (1U<<'+'-' ')
#define GROUPED    (1U<<'\''-' ')

#define FLAGMASK (ALT_FORM|ZERO_PAD|LEFT_ADJ|PAD_POS|MARK_POS|GROUPED)

/* State machine to accept length modifiers + conversion specifiers.
 * Result is 0 on failure, or an argument type to pop on success. */

enum {
	BARE, LPRE, LLPRE, HPRE, HHPRE, BIGLPRE,
	ZTPRE, JPRE,
	STOP,
	PTR, INT, UINT, ULLONG,
	LONG, ULONG,
	SHORT, USHORT, CHAR, UCHAR,
	LLONG, SIZET, IMAX, UMAX, PDIFF, UIPTR,
	DBL, LDBL,
	NOARG,
	MAXSTATE
};

#define S(x) [(x)-'A']

static const unsigned char states[]['z'-'A'+1] = {
	{ /* 0: bare types */
		S('d') = INT, S('i') = INT,
		S('o') = UINT, S('u') = UINT, S('x') = UINT, S('X') = UINT,
		S('e') = DBL, S('f') = DBL, S('g') = DBL, S('a') = DBL,
		S('E') = DBL, S('F') = DBL, S('G') = DBL, S('A') = DBL,
		S('c') = CHAR, S('C') = INT,
		S('s') = PTR, S('S') = PTR, S('p') = UIPTR, S('n') = PTR,
		S('m') = NOARG,
		S('l') = LPRE, S('h') = HPRE, S('L') = BIGLPRE,
		S('z') = ZTPRE, S('j') = JPRE, S('t') = ZTPRE,
	}, { /* 1: l-prefixed */
		S('d') = LONG, S('i') = LONG,
		S('o') = ULONG, S('u') = ULONG, S('x') = ULONG, S('X') = ULONG,
		S('e') = DBL, S('f') = DBL, S('g') = DBL, S('a') = DBL,
		S('E') = DBL, S('F') = DBL, S('G') = DBL, S('A') = DBL,
		S('c') = INT, S('s') = PTR, S('n') = PTR,
		S('l') = LLPRE,
	}, { /* 2: ll-prefixed */
		S('d') = LLONG, S('i') = LLONG,
		S('o') = ULLONG, S('u') = ULLONG,
		S('x') = ULLONG, S('X') = ULLONG,
		S('n') = PTR,
	}, { /* 3: h-prefixed */
		S('d') = SHORT, S('i') = SHORT,
		S('o') = USHORT, S('u') = USHORT,
		S('x') = USHORT, S('X') = USHORT,
		S('n') = PTR,
		S('h') = HHPRE,
	}, { /* 4: hh-prefixed */
		S('d') = CHAR, S('i') = CHAR,
		S('o') = UCHAR, S('u') = UCHAR,
		S('x') = UCHAR, S('X') = UCHAR,
		S('n') = PTR,
	}, { /* 5: L-prefixed */
		S('e') = LDBL, S('f') = LDBL, S('g') = LDBL, S('a') = LDBL,
		S('E') = LDBL, S('F') = LDBL, S('G') = LDBL, S('A') = LDBL,
		S('n') = PTR,
	}, { /* 6: z- or t-prefixed (assumed to be same size) */
		S('d') = PDIFF, S('i') = PDIFF,
		S('o') = SIZET, S('u') = SIZET,
		S('x') = SIZET, S('X') = SIZET,
		S('n') = PTR,
	}, { /* 7: j-prefixed */
		S('d') = IMAX, S('i') = IMAX,
		S('o') = UMAX, S('u') = UMAX,
		S('x') = UMAX, S('X') = UMAX,
		S('n') = PTR,
	}
};

#define OOB(x) ((unsigned)(x)-'A' > 'z'-'A')

union arg
{
	uintmax_t i;
	long double f;
	void *p;
};

static void pop_arg(union arg *arg, int type, va_list *ap)
{
	switch (type) {
	       case PTR:	arg->p = va_arg(*ap, void *);
	break; case INT:	arg->i = va_arg(*ap, int);
	break; case UINT:	arg->i = va_arg(*ap, unsigned int);
	break; case LONG:	arg->i = va_arg(*ap, long);
	break; case ULONG:	arg->i = va_arg(*ap, unsigned long);
	break; case ULLONG:	arg->i = va_arg(*ap, unsigned long long);
	break; case SHORT:	arg->i = (short)va_arg(*ap, int);
	break; case USHORT:	arg->i = (unsigned short)va_arg(*ap, int);
	break; case CHAR:	arg->i = (signed char)va_arg(*ap, int);
	break; case UCHAR:	arg->i = (unsigned char)va_arg(*ap, int);
	break; case LLONG:	arg->i = va_arg(*ap, long long);
	break; case SIZET:	arg->i = va_arg(*ap, size_t);
	break; case IMAX:	arg->i = va_arg(*ap, intmax_t);
	break; case UMAX:	arg->i = va_arg(*ap, uintmax_t);
	break; case PDIFF:	arg->i = va_arg(*ap, ptrdiff_t);
	break; case UIPTR:	arg->i = (uintptr_t)va_arg(*ap, void *);
	break; case DBL:	arg->f = va_arg(*ap, double);
	break; case LDBL:	arg->f = va_arg(*ap, long double);
	}
}

static void out(FILE *f, const wchar_t *s, size_t l)
{
	while (l-- && !(f->flags & F_ERR)) fputwc(*s++, f);
}

static int getint(wchar_t **s) {
	int i;
	for (i=0; iswdigit(**s); (*s)++) {
		if (i > INT_MAX/10U || **s-'0' > INT_MAX-10*i) i = -1;
		else i = 10*i + (**s-'0');
	}
	return i;
}

static const char sizeprefix['y'-'a'] = {
['a'-'a']='L', ['e'-'a']='L', ['f'-'a']='L', ['g'-'a']='L',
['d'-'a']='j', ['i'-'a']='j', ['o'-'a']='j', ['u'-'a']='j', ['x'-'a']='j',
['p'-'a']='j'
};

static int wprintf_core(FILE *f, const wchar_t *fmt, va_list *ap, union arg *nl_arg, int *nl_type)
{
	wchar_t *a, *z, *s=(wchar_t *)fmt;
	unsigned l10n=0, fl;
	int w, p, xp;
	union arg arg;
	int argpos;
	unsigned st, ps;
	int cnt=0, l=0;
	int i;
	int t;
	char *bs;
	char charfmt[16];
	wchar_t wc;

	for (;;) {
		/* This error is only specified for snprintf, but since it's
		 * unspecified for other forms, do the same. Stop immediately
		 * on overflow; otherwise %n could produce wrong results. */
		if (l > INT_MAX - cnt) goto overflow;

		/* Update output count, end loop when fmt is exhausted */
		cnt += l;
		if (!*s) break;

		/* Handle literal text and %% format specifiers */
		for (a=s; *s && *s!='%'; s++);
		for (z=s; s[0]=='%' && s[1]=='%'; z++, s+=2);
		if (z-a > INT_MAX-cnt) goto overflow;
		l = z-a;
		if (f) out(f, a, l);
		if (l) continue;

		if (iswdigit(s[1]) && s[2]=='$') {
			l10n=1;
			argpos = s[1]-'0';
			s+=3;
		} else {
			argpos = -1;
			s++;
		}

		/* Read modifier flags */
		for (fl=0; (unsigned)*s-' '<32 && (FLAGMASK&(1U<<*s-' ')); s++)
			fl |= 1U<<*s-' ';

		/* Read field width */
		if (*s=='*') {
			if (iswdigit(s[1]) && s[2]=='$') {
				l10n=1;
				nl_type[s[1]-'0'] = INT;
				w = nl_arg[s[1]-'0'].i;
				s+=3;
			} else if (!l10n) {
				w = f ? va_arg(*ap, int) : 0;
				s++;
			} else goto inval;
			if (w<0) fl|=LEFT_ADJ, w=-w;
		} else if ((w=getint(&s))<0) goto overflow;

		/* Read precision */
		if (*s=='.' && s[1]=='*') {
			if (isdigit(s[2]) && s[3]=='$') {
				nl_type[s[2]-'0'] = INT;
				p = nl_arg[s[2]-'0'].i;
				s+=4;
			} else if (!l10n) {
				p = f ? va_arg(*ap, int) : 0;
				s+=2;
			} else goto inval;
			xp = (p>=0);
		} else if (*s=='.') {
			s++;
			p = getint(&s);
			xp = 1;
		} else {
			p = -1;
			xp = 0;
		}

		/* Format specifier state machine */
		st=0;
		do {
			if (OOB(*s)) goto inval;
			ps=st;
			st=states[st]S(*s++);
		} while (st-1<STOP);
		if (!st) goto inval;

		/* Check validity of argument type (nl/normal) */
		if (st==NOARG) {
			if (argpos>=0) goto inval;
		} else {
			if (argpos>=0) nl_type[argpos]=st, arg=nl_arg[argpos];
			else if (f) pop_arg(&arg, st, ap);
			else return 0;
		}

		if (!f) continue;
		t = s[-1];
		if (ps && (t&15)==3) t&=~32;

		switch (t) {
		case 'n':
			switch(ps) {
			case BARE: *(int *)arg.p = cnt; break;
			case LPRE: *(long *)arg.p = cnt; break;
			case LLPRE: *(long long *)arg.p = cnt; break;
			case HPRE: *(unsigned short *)arg.p = cnt; break;
			case HHPRE: *(unsigned char *)arg.p = cnt; break;
			case ZTPRE: *(size_t *)arg.p = cnt; break;
			case JPRE: *(uintmax_t *)arg.p = cnt; break;
			}
			continue;
		case 'c':
			if (w<1) w=1;
			if (w>1 && !(fl&LEFT_ADJ)) fprintf(f, "%*s", w-1, "");
			fputwc(btowc(arg.i), f);
			if (w>1 && (fl&LEFT_ADJ)) fprintf(f, "%*s", w-1, "");
			l = w;
			continue;
		case 'C':
			fputwc(arg.i, f);
			l = 1;
			continue;
		case 'S':
			a = arg.p;
			z = a + wcsnlen(a, p<0 ? INT_MAX : p);
			if (p<0 && *z) goto overflow;
			p = z-a;
			if (w<p) w=p;
			if (!(fl&LEFT_ADJ)) fprintf(f, "%*s", w-p, "");
			out(f, a, p);
			if ((fl&LEFT_ADJ)) fprintf(f, "%*s", w-p, "");
			l=w;
			continue;
		case 'm':
			arg.p = strerror(errno);
		case 's':
			if (!arg.p) arg.p = "(null)";
			bs = arg.p;
			for (i=l=0; l<(p<0?INT_MAX:p) && (i=mbtowc(&wc, bs, MB_LEN_MAX))>0; bs+=i, l++);
			if (i<0) return -1;
			if (p<0 && *bs) goto overflow;
			p=l;
			if (w<p) w=p;
			if (!(fl&LEFT_ADJ)) fprintf(f, "%*s", w-p, "");
			bs = arg.p;
			while (l--) {
				i=mbtowc(&wc, bs, MB_LEN_MAX);
				bs+=i;
				fputwc(wc, f);
			}
			if ((fl&LEFT_ADJ)) fprintf(f, "%*s", w-p, "");
			l=w;
			continue;
		}

		if (xp && p<0) goto overflow;
		snprintf(charfmt, sizeof charfmt, "%%%s%s%s%s%s*.*%c%c",
			"#"+!(fl & ALT_FORM),
			"+"+!(fl & MARK_POS),
			"-"+!(fl & LEFT_ADJ),
			" "+!(fl & PAD_POS),
			"0"+!(fl & ZERO_PAD),
			sizeprefix[(t|32)-'a'], t);

		switch (t|32) {
		case 'a': case 'e': case 'f': case 'g':
			l = fprintf(f, charfmt, w, p, arg.f);
			break;
		case 'd': case 'i': case 'o': case 'u': case 'x': case 'p':
			l = fprintf(f, charfmt, w, p, arg.i);
			break;
		}
	}

	if (f) return cnt;
	if (!l10n) return 0;

	for (i=1; i<=NL_ARGMAX && nl_type[i]; i++)
		pop_arg(nl_arg+i, nl_type[i], ap);
	for (; i<=NL_ARGMAX && !nl_type[i]; i++);
	if (i<=NL_ARGMAX) return -1;
	return 1;

inval:
	errno = EINVAL;
	return -1;
overflow:
	errno = EOVERFLOW;
	return -1;
}

int vfwprintf(FILE *restrict f, const wchar_t *restrict fmt, va_list ap)
{
	va_list ap2;
	int nl_type[NL_ARGMAX] = {0};
	union arg nl_arg[NL_ARGMAX];
	int olderr;
	int ret;

	/* the copy allows passing va_list* even if va_list is an array */
	va_copy(ap2, ap);
	if (wprintf_core(0, fmt, &ap2, nl_arg, nl_type) < 0) {
		va_end(ap2);
		return -1;
	}

	FLOCK(f);
	fwide(f, 1);
	olderr = f->flags & F_ERR;
	f->flags &= ~F_ERR;
	ret = wprintf_core(f, fmt, &ap2, nl_arg, nl_type);
	if (f->flags & F_ERR) ret = -1;
	f->flags |= olderr;
	FUNLOCK(f);
	va_end(ap2);
	return ret;
}
