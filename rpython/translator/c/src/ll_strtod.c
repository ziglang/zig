#include <src/ll_strtod.h>

#include <locale.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>


double LL_strtod_parts_to_float(char *sign, char *beforept, 
				char *afterpt, char *exponent)
{
    char *fail_pos;
    struct lconv *locale_data;
    const char *decimal_point;
    int decimal_point_len;
    double x;
    char *last;
    char *expo = exponent;
    int buf_size;
    char *s;

    if (*expo == '\0') {
	expo = "0";
    }

    locale_data = localeconv();
    decimal_point = locale_data->decimal_point;
    decimal_point_len = strlen(decimal_point);

    buf_size = strlen(sign) + 
	strlen(beforept) +
	decimal_point_len +
	strlen(afterpt) +
	1 /* e */ +
	strlen(expo) + 
	1 /*  asciiz  */ ;

    s = (char*)malloc(buf_size);

    strcpy(s, sign);
    strcat(s, beforept);
    strcat(s, decimal_point);
    strcat(s, afterpt);
    strcat(s, "e");
    strcat(s, expo);

    last = s + (buf_size-1);
    x = strtod(s, &fail_pos);
    errno = 0;
    if (fail_pos > last)
	fail_pos = last;
    if (fail_pos == s || *fail_pos != '\0' || fail_pos != last) {
	free(s);
	errno = 42; // just because
	return -1.0;
    }
    if (x == 0.0) { /* maybe a denormal value, ask for atof behavior */
	x = strtod(s, NULL);
	errno = 0;
    }
    free(s);
    return x;
}

static char buffer[120]; /* this should be enough, from PyString_Format code */
static const int buflen = 120;

#ifdef _MSC_VER
#define snprintf _snprintf
#endif

char* LL_strtod_formatd(double x, char code, int precision)
{
    int res;
    const char* fmt;
    if (code == 'e') fmt = "%.*e";
    else if (code == 'f') fmt = "%.*f";
    else if (code == 'g') fmt = "%.*g";
    else {
	strcpy(buffer, "??.?"); /* should not occur */
	return buffer;
    }
    res = snprintf(buffer, buflen, fmt, precision, x);
    if (res <= 0 || res >= buflen) {
	strcpy(buffer, "??.?"); /* should not occur */
    } else {
	struct lconv *locale_data;
	const char *decimal_point;
	int decimal_point_len;
	char *p;

	locale_data = localeconv();
	decimal_point = locale_data->decimal_point;
	decimal_point_len = strlen(decimal_point);

	if (decimal_point[0] != '.' || 
	    decimal_point[1] != 0)
	{
	    p = buffer;

	    if (*p == '+' || *p == '-')
		p++;

	    while (isdigit((unsigned char)*p))
		p++;

	    if (strncmp(p, decimal_point, decimal_point_len) == 0)
	    {
		*p = '.';
		p++;
		if (decimal_point_len > 1) {
		    int rest_len;
		    rest_len = strlen(p + (decimal_point_len - 1));
		    memmove(p, p + (decimal_point_len - 1), 
			    rest_len);
		    p[rest_len] = 0;
		}
	    }
	}
		
    }

    return buffer;
}
