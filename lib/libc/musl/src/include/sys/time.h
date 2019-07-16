#ifndef SYS_TIME_H
#define SYS_TIME_H

#include_next "sys/time.h"

hidden int __futimesat(int, const char *, const struct timeval [2]);

#endif
