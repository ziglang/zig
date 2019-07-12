/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_ERRNO
#define _INC_ERRNO

#include <crtdefs.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _CRT_ERRNO_DEFINED
#define _CRT_ERRNO_DEFINED
_CRTIMP extern int *__cdecl _errno(void);
#define errno (*_errno())

errno_t __cdecl _set_errno(int _Value);
errno_t __cdecl _get_errno(int *_Value);
#endif /* _CRT_ERRNO_DEFINED */

#define EPERM 1
#define ENOENT 2
#define ENOFILE ENOENT
#define ESRCH 3
#define EINTR 4
#define EIO 5
#define ENXIO 6
#define E2BIG 7
#define ENOEXEC 8
#define EBADF 9
#define ECHILD 10
#define EAGAIN 11
#define ENOMEM 12
#define EACCES 13
#define EFAULT 14
#define EBUSY 16
#define EEXIST 17
#define EXDEV 18
#define ENODEV 19
#define ENOTDIR 20
#define EISDIR 21
#define ENFILE 23
#define EMFILE 24
#define ENOTTY 25
#define EFBIG 27
#define ENOSPC 28
#define ESPIPE 29
#define EROFS 30
#define EMLINK 31
#define EPIPE 32
#define EDOM 33
#define EDEADLK 36
#define ENAMETOOLONG 38
#define ENOLCK 39
#define ENOSYS 40
#define ENOTEMPTY 41

#ifndef RC_INVOKED
#if !defined(_SECURECRT_ERRCODE_VALUES_DEFINED)
#define _SECURECRT_ERRCODE_VALUES_DEFINED
#define EINVAL 22
#define ERANGE 34
#define EILSEQ 42
#define STRUNCATE 80
#endif
#endif

#define EDEADLOCK EDEADLK

/* Posix thread extensions.  */

#ifndef ENOTSUP
#define ENOTSUP         129
#endif

/* Extension defined as by report VC 10+ defines error-numbers.  */

#ifndef EAFNOSUPPORT
#define EAFNOSUPPORT 102
#endif

#ifndef EADDRINUSE
#define EADDRINUSE 100
#endif

#ifndef EADDRNOTAVAIL
#define EADDRNOTAVAIL 101
#endif

#ifndef EISCONN
#define EISCONN 113
#endif

#ifndef ENOBUFS
#define ENOBUFS 119
#endif

#ifndef ECONNABORTED
#define ECONNABORTED 106
#endif

#ifndef EALREADY
#define EALREADY 103
#endif

#ifndef ECONNREFUSED
#define ECONNREFUSED 107
#endif

#ifndef ECONNRESET
#define ECONNRESET 108
#endif

#ifndef EDESTADDRREQ
#define EDESTADDRREQ 109
#endif

#ifndef EHOSTUNREACH
#define EHOSTUNREACH 110
#endif

#ifndef EMSGSIZE
#define EMSGSIZE 115
#endif

#ifndef ENETDOWN
#define ENETDOWN 116
#endif

#ifndef ENETRESET
#define ENETRESET 117
#endif

#ifndef ENETUNREACH
#define ENETUNREACH 118
#endif

#ifndef ENOPROTOOPT
#define ENOPROTOOPT 123
#endif

#ifndef ENOTSOCK
#define ENOTSOCK 128
#endif

#ifndef ENOTCONN
#define ENOTCONN 126
#endif

#ifndef ECANCELED
#define ECANCELED 105
#endif

#ifndef EINPROGRESS
#define EINPROGRESS 112
#endif

#ifndef EOPNOTSUPP
#define EOPNOTSUPP 130
#endif

#ifndef EWOULDBLOCK
#define EWOULDBLOCK 140
#endif

#ifndef EOWNERDEAD
#define EOWNERDEAD 133
#endif

#ifndef EPROTO
#define EPROTO 134
#endif

#ifndef EPROTONOSUPPORT
#define EPROTONOSUPPORT 135
#endif

#ifndef EBADMSG
#define EBADMSG 104
#endif

#ifndef EIDRM
#define EIDRM 111
#endif

#ifndef ENODATA
#define ENODATA 120
#endif

#ifndef ENOLINK
#define ENOLINK 121
#endif

#ifndef ENOMSG
#define ENOMSG 122
#endif

#ifndef ENOSR
#define ENOSR 124
#endif

#ifndef ENOSTR
#define ENOSTR 125
#endif

#ifndef ENOTRECOVERABLE
#define ENOTRECOVERABLE 127
#endif

#ifndef ETIME
#define ETIME 137
#endif

#ifndef ETXTBSY
#define ETXTBSY 139
#endif

/* Defined as WSAETIMEDOUT.  */
#ifndef ETIMEDOUT
#define ETIMEDOUT 138
#endif

#ifndef ELOOP
#define ELOOP 114
#endif

#ifndef EPROTOTYPE
#define EPROTOTYPE 136
#endif

#ifndef EOVERFLOW
#define EOVERFLOW 132
#endif

#ifdef __cplusplus
}
#endif
#endif
