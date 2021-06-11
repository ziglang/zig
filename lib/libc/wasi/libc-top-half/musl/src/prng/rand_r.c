#include <stdlib.h>

static unsigned temper(unsigned x)
{
	x ^= x>>11;
	x ^= x<<7 & 0x9D2C5680;
	x ^= x<<15 & 0xEFC60000;
	x ^= x>>18;
	return x;
}

int rand_r(unsigned *seed)
{
	return temper(*seed = *seed * 1103515245 + 12345)/2;
}
