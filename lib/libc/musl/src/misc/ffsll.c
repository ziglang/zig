#include <strings.h>
#include "atomic.h"

int ffsll(long long i)
{
	return i ? a_ctz_64(i)+1 : 0;
}
