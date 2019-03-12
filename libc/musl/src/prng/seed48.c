#include <stdlib.h>
#include <string.h>
#include "rand48.h"

unsigned short *seed48(unsigned short *s)
{
	static unsigned short p[3];
	memcpy(p, __seed48, sizeof p);
	memcpy(__seed48, s, sizeof p);
	return p;
}
