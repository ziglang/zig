/* For UCRT, positive infinity */
#include <_mingw.h>
#undef _HUGE
static double _HUGE = __builtin_huge_val();
double * __MINGW_IMP_SYMBOL(_HUGE) = &_HUGE;
#undef HUGE
extern double * __attribute__ ((alias (__MINGW64_STRINGIFY(__MINGW_IMP_SYMBOL(_HUGE))))) __MINGW_IMP_SYMBOL(HUGE);
