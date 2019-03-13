#include <float.h>
#include <fenv.h>

int __flt_rounds()
{
	switch (fegetround()) {
#ifdef FE_TOWARDZERO
	case FE_TOWARDZERO: return 0;
#endif
	case FE_TONEAREST: return 1;
#ifdef FE_UPWARD
	case FE_UPWARD: return 2;
#endif
#ifdef FE_DOWNWARD
	case FE_DOWNWARD: return 3;
#endif
	}
	return -1;
}
