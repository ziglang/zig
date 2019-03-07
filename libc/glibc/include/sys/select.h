#ifndef _SYS_SELECT_H
#include <misc/sys/select.h>

#ifndef _ISOMAC
/* Now define the internal interfaces.  */
extern int __pselect (int __nfds, fd_set *__readfds,
		      fd_set *__writefds, fd_set *__exceptfds,
		      const struct timespec *__timeout,
		      const __sigset_t *__sigmask);

extern int __select (int __nfds, fd_set *__restrict __readfds,
		     fd_set *__restrict __writefds,
		     fd_set *__restrict __exceptfds,
		     struct timeval *__restrict __timeout);
libc_hidden_proto (__select)

#endif
#endif
