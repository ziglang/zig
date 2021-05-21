#include <inttypes.h>

imaxdiv_t imaxdiv(intmax_t num, intmax_t den)
{
	return (imaxdiv_t){ num/den, num%den };
}
