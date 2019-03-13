#include <stdlib.h>
#include <ctype.h>

long long atoll(const char *s)
{
	long long n=0;
	int neg=0;
	while (isspace(*s)) s++;
	switch (*s) {
	case '-': neg=1;
	case '+': s++;
	}
	/* Compute n as a negative number to avoid overflow on LLONG_MIN */
	while (isdigit(*s))
		n = 10*n - (*s++ - '0');
	return neg ? n : -n;
}
