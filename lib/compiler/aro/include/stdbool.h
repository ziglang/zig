/* <stdbool.h> for the Aro C compiler */

#pragma once

#if __STDC_VERSION__ < 202311L
#define bool _Bool

#define true 1
#define false 0

#define __bool_true_false_are_defined 1

#endif
