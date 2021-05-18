#ifndef __wasilibc_sys_select_h
#define __wasilibc_sys_select_h

#include <__fd_set.h>
#include <__struct_timespec.h>
#include <__struct_timeval.h>

#ifdef __cplusplus
extern "C" {
#endif

int pselect(int, fd_set *, fd_set *, fd_set *, const struct timespec *, const sigset_t *);

#ifdef __cplusplus
}
#endif

#endif
