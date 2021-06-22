#include <stdio.h>
#include <ctype.h>
#include <stdarg.h>
#include <monetary.h>
#include <errno.h>
#include "locale_impl.h"

static ssize_t vstrfmon_l(char *s, size_t n, locale_t loc, const char *fmt, va_list ap)
{
	size_t l;
	double x;
	int fill, nogrp, negpar, nosym, left, intl;
	int lp, rp, w, fw;
	char *s0=s;
	for (; n && *fmt; ) {
		if (*fmt != '%') {
		literal:
			*s++ = *fmt++;
			n--;
			continue;
		}
		fmt++;
		if (*fmt == '%') goto literal;

		fill = ' ';
		nogrp = 0;
		negpar = 0;
		nosym = 0;
		left = 0;
		for (; ; fmt++) {
			switch (*fmt) {
			case '=':
				fill = *++fmt;
				continue;
			case '^':
				nogrp = 1;
				continue;
			case '(':
				negpar = 1;
			case '+':
				continue;
			case '!':
				nosym = 1;
				continue;
			case '-':
				left = 1;
				continue;
			}
			break;
		}

		for (fw=0; isdigit(*fmt); fmt++)
			fw = 10*fw + (*fmt-'0');
		lp = 0;
		rp = 2;
		if (*fmt=='#') for (lp=0, fmt++; isdigit(*fmt); fmt++)
			lp = 10*lp + (*fmt-'0');
		if (*fmt=='.') for (rp=0, fmt++; isdigit(*fmt); fmt++)
			rp = 10*rp + (*fmt-'0');

		intl = *fmt++ == 'i';

		w = lp + 1 + rp;
		if (!left && fw>w) w = fw;

		x = va_arg(ap, double);
		l = snprintf(s, n, "%*.*f", w, rp, x);
		if (l >= n) {
			errno = E2BIG;
			return -1;
		}
		s += l;
		n -= l;
	}
	return s-s0;
}

ssize_t strfmon_l(char *restrict s, size_t n, locale_t loc, const char *restrict fmt, ...)
{
	va_list ap;
	ssize_t ret;

	va_start(ap, fmt);
	ret = vstrfmon_l(s, n, loc, fmt, ap);
	va_end(ap);

	return ret;
}


ssize_t strfmon(char *restrict s, size_t n, const char *restrict fmt, ...)
{
	va_list ap;
	ssize_t ret;

	va_start(ap, fmt);
	ret = vstrfmon_l(s, n, CURRENT_LOCALE, fmt, ap);
	va_end(ap);

	return ret;
}
