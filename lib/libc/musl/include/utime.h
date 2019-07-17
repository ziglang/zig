#ifndef	_UTIME_H
#define	_UTIME_H

#ifdef __cplusplus
extern "C" {
#endif

#define __NEED_time_t

#include <bits/alltypes.h>

struct utimbuf {
	time_t actime;
	time_t modtime;
};

int utime (const char *, const struct utimbuf *);

#ifdef __cplusplus
}
#endif

#endif
