#include <stdlib.h>

#ifndef __cplusplus
#define static_assert _Static_assert
#endif

#define assert(x) ((void)((x) || (abort(), 0)))
