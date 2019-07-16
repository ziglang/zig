#ifndef SYS_AUXV_H
#define SYS_AUXV_H

#include_next "sys/auxv.h"

#include <features.h>

hidden unsigned long __getauxval(unsigned long);

#endif
