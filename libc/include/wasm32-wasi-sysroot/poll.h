#ifndef	_POLL_H
#define	_POLL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>

#include <bits/poll.h>

#ifdef __wasilibc_unmodified_upstream /* Use alternate WASI libc headers */
#define POLLIN     0x001
#define POLLPRI    0x002
#define POLLOUT    0x004
#define POLLERR    0x008
#define POLLHUP    0x010
#define POLLNVAL   0x020
#define POLLRDNORM 0x040
#define POLLRDBAND 0x080
#ifndef POLLWRNORM
#define POLLWRNORM 0x100
#define POLLWRBAND 0x200
#endif
#ifndef POLLMSG
#define POLLMSG    0x400
#define POLLRDHUP  0x2000
#endif
#else
#include <__header_poll.h>
#endif

#ifdef __wasilibc_unmodified_upstream /* Use alternate WASI libc headers */
typedef unsigned long nfds_t;
#else
#include <__typedef_nfds_t.h>
#endif

#ifdef __wasilibc_unmodified_upstream /* Use alternate WASI libc headers */
struct pollfd {
	int fd;
	short events;
	short revents;
};
#else
#include <__struct_pollfd.h>
#endif

int poll (struct pollfd *, nfds_t, int);

#ifdef _GNU_SOURCE
#define __NEED_time_t
#define __NEED_struct_timespec
#define __NEED_sigset_t
#include <bits/alltypes.h>
int ppoll(struct pollfd *, nfds_t, const struct timespec *, const sigset_t *);
#endif

#ifdef __cplusplus
}
#endif

#endif
