#ifndef _SYS_SELECT_H
#include <misc/sys/select.h>

#ifndef _ISOMAC
/* Now define the internal interfaces.  */

#include <bits/select-decl.h>
libc_hidden_proto (__fdelt_chk)

# if __TIMESIZE == 64
#  define __pselect64 __pselect
#  define __select64  __select
#else
# include <struct___timespec64.h>
# include <struct___timeval64.h>

extern int __pselect64 (int __nfds, fd_set *__readfds,
			fd_set *__writefds, fd_set *__exceptfds,
			const struct __timespec64 *__timeout,
			const __sigset_t *__sigmask);
libc_hidden_proto (__pselect64)

extern int __pselect32 (int __nfds, fd_set *__readfds,
			fd_set *__writefds, fd_set *__exceptfds,
			const struct __timespec64 *__timeout,
			const __sigset_t *__sigmask)
  attribute_hidden;
extern int __select32 (int __nfds, fd_set *__readfds,
		       fd_set *__writefds, fd_set *__exceptfds,
		       const struct __timespec64 *ts64,
		       struct __timeval64 *timeout)
  attribute_hidden;

extern int __select64 (int __nfds, fd_set *__readfds,
		       fd_set *__writefds, fd_set *__exceptfds,
		       struct __timeval64 *__timeout);
libc_hidden_proto (__select64)
#endif
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
