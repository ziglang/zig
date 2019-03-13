#include <resolv.h>

int dn_skipname(const unsigned char *s, const unsigned char *end)
{
	const unsigned char *p;
	for (p=s; p<end; p++)
		if (!*p) return p-s+1;
		else if (*p>=192)
			if (p+1<end) return p-s+2;
			else break;
	return -1;
}
