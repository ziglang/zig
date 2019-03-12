#ifndef ERRNO_H
#define ERRNO_H

#include_next "errno.h"

hidden int *___errno_location(void);

#undef errno
#define errno (*___errno_location())

#endif
