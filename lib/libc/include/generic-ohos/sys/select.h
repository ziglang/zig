#ifndef _SYS_SELECT_H
#define _SYS_SELECT_H
#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>

#define __NEED_size_t
#define __NEED_time_t
#define __NEED_suseconds_t
#define __NEED_struct_timeval
#define __NEED_struct_timespec
#define __NEED_sigset_t

#include <bits/alltypes.h>

#define FD_SETSIZE 1024

typedef unsigned long fd_mask;

typedef struct {
	unsigned long fds_bits[FD_SETSIZE / 8 / sizeof(long)];
} fd_set;

/**
* @brief Check if fd passed to fd_set is valid (<1024).
*
* This method will check fd(0 <= fd < 1024) is valid for select, abort if not.
*
* @param fd: Specified fd.
*/
void __fd_chk(int fd);

#define FD_ZERO(s) do { int __i; unsigned long *__b=(s)->fds_bits; for(__i=sizeof (fd_set)/sizeof (long); __i; __i--) *__b++=0; } while(0)
#define FD_SET(d, s) do { __fd_chk(d); ((s)->fds_bits[(d)/(8*sizeof(long))] |= (1UL<<((d)%(8*sizeof(long))))); } while(0)
#define FD_CLR(d, s) do { __fd_chk(d); ((s)->fds_bits[(d)/(8*sizeof(long))] &= ~(1UL<<((d)%(8*sizeof(long))))); } while(0)
#define FD_ISSET(d, s) ((d) >= 0 && (d) < FD_SETSIZE && (!!((s)->fds_bits[(d)/(8*sizeof(long))] & (1UL<<((d)%(8*sizeof(long)))))))

int select (int, fd_set *__restrict, fd_set *__restrict, fd_set *__restrict, struct timeval *__restrict);
int pselect (int, fd_set *__restrict, fd_set *__restrict, fd_set *__restrict, const struct timespec *__restrict, const sigset_t *__restrict);

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#define NFDBITS (8*(int)sizeof(long))
#endif

#if _REDIR_TIME64
__REDIR(select, __select_time64);
__REDIR(pselect, __pselect_time64);
#endif

#ifdef __cplusplus
}
#endif
#endif
