/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef ___WSA_FD_TYPES_H
#define ___WSA_FD_TYPES_H

#include <psdk_inc/_socket_types.h>

#ifndef FD_SETSIZE
#define FD_SETSIZE	64
#endif

#ifndef _SYS_TYPES_FD_SET
/* fd_set may have been defined by the newlib <sys/types.h>
 * if  __USE_W32_SOCKETS not defined.
 */

typedef struct fd_set
{
	u_int	fd_count;
	SOCKET	fd_array[FD_SETSIZE];
} fd_set;

#ifdef __cplusplus
extern "C" {
#endif

int WINAPI __WSAFDIsSet(SOCKET,fd_set *);

#ifdef __cplusplus
}
#endif

#ifndef FD_CLR
#define FD_CLR(fd,set)							\
  do {									\
	u_int __i;							\
	for(__i = 0; __i < ((fd_set *)(set))->fd_count; __i++) {	\
		if (((fd_set *)(set))->fd_array[__i] == fd) {		\
			while (__i < ((fd_set *)(set))->fd_count - 1) {	\
				((fd_set *)(set))->fd_array[__i] =	\
				 ((fd_set *)(set))->fd_array[__i + 1];	\
				__i++;					\
			}						\
			((fd_set *)(set))->fd_count--;			\
			break;						\
		}							\
	}								\
  } while(0)
#endif /* !FD_CLR */

#ifndef FD_ZERO
#define FD_ZERO(set)		(((fd_set *)(set))->fd_count = 0)
#endif /* !FD_ZERO */

#ifndef FD_ISSET
#define FD_ISSET(fd,set)	__WSAFDIsSet((SOCKET)(fd),(fd_set *)(set))
#endif /* !FD_ISSET */

/* FD_SET is differently implement in winsock.h and winsock2.h.  If we
   encounter that we are going to redefine it, and if the original definition
   is from winsock.h, make sure to undef FD_SET so it can be redefined to
   the winsock2.h version. */
#ifdef _FD_SET_WINSOCK_DEFINED
#undef _FD_SET_WINSOCK_DEFINED
#undef FD_SET
#endif
#ifndef FD_SET
#ifdef _WINSOCK2API_
#define FD_SET(fd,set)							\
  do {									\
	u_int __i;							\
	for(__i = 0; __i < ((fd_set *)(set))->fd_count; __i++) {	\
		if (((fd_set *)(set))->fd_array[__i] == (fd)) {		\
			break;						\
		}							\
	}								\
	if (__i == ((fd_set *)(set))->fd_count) {			\
		if (((fd_set *)(set))->fd_count < FD_SETSIZE) {		\
			((fd_set *)(set))->fd_array[__i] = (fd);	\
			((fd_set *)(set))->fd_count++;			\
		}							\
	}								\
  } while(0)
#else
#define _FD_SET_WINSOCK_DEFINED
#define FD_SET(fd,set)							\
  do {									\
	if (((fd_set *)(set))->fd_count < FD_SETSIZE)			\
	    ((fd_set *)(set))->fd_array[((fd_set *)(set))->fd_count++] =\
								   (fd);\
  } while(0)
#endif /* _WINSOCK2API_ */
#endif /* !FD_SET */

#elif !defined(USE_SYS_TYPES_FD_SET)
#warning "fd_set and associated macros have been defined in sys/types.  \
    This can cause runtime problems with W32 sockets"
#endif /* !_SYS_TYPES_FD_SET */

typedef struct fd_set	FD_SET;
typedef struct fd_set	*PFD_SET;
typedef struct fd_set	*LPFD_SET;

#endif /* ___WSA_FD_TYPES_H */

