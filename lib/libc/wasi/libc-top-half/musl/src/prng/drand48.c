#include <stdlib.h>
#include <inttypes.h>
#include "rand48.h"

double erand48(unsigned short s[3])
{
	union {
		uint64_t u;
		double f;
	} x = { 0x3ff0000000000000ULL | __rand48_step(s, __seed48+3)<<4 };
	return x.f - 1.0;
}

double drand48(void)
{
	return erand48(__seed48);
}
