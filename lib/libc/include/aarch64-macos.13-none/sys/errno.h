/*
 * Copyright (c) 2000-2012 Apple, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1982, 1986, 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)errno.h	8.5 (Berkeley) 1/21/94
 */

#ifndef _SYS_ERRNO_H_
#define _SYS_ERRNO_H_

#include <sys/cdefs.h>


#if defined(__STDC_WANT_LIB_EXT1__) && __STDC_WANT_LIB_EXT1__ >= 1
#include <sys/_types/_errno_t.h>
#endif

__BEGIN_DECLS
extern int * __error(void);
#define errno (*__error())
__END_DECLS

/*
 * Error codes
 */

#define EPERM           1               /* Operation not permitted */
#define ENOENT          2               /* No such file or directory */
#define ESRCH           3               /* No such process */
#define EINTR           4               /* Interrupted system call */
#define EIO             5               /* Input/output error */
#define ENXIO           6               /* Device not configured */
#define E2BIG           7               /* Argument list too long */
#define ENOEXEC         8               /* Exec format error */
#define EBADF           9               /* Bad file descriptor */
#define ECHILD          10              /* No child processes */
#define EDEADLK         11              /* Resource deadlock avoided */
                                        /* 11 was EAGAIN */
#define ENOMEM          12              /* Cannot allocate memory */
#define EACCES          13              /* Permission denied */
#define EFAULT          14              /* Bad address */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define ENOTBLK         15              /* Block device required */
#endif
#define EBUSY           16              /* Device / Resource busy */
#define EEXIST          17              /* File exists */
#define EXDEV           18              /* Cross-device link */
#define ENODEV          19              /* Operation not supported by device */
#define ENOTDIR         20              /* Not a directory */
#define EISDIR          21              /* Is a directory */
#define EINVAL          22              /* Invalid argument */
#define ENFILE          23              /* Too many open files in system */
#define EMFILE          24              /* Too many open files */
#define ENOTTY          25              /* Inappropriate ioctl for device */
#define ETXTBSY         26              /* Text file busy */
#define EFBIG           27              /* File too large */
#define ENOSPC          28              /* No space left on device */
#define ESPIPE          29              /* Illegal seek */
#define EROFS           30              /* Read-only file system */
#define EMLINK          31              /* Too many links */
#define EPIPE           32              /* Broken pipe */

/* math software */
#define EDOM            33              /* Numerical argument out of domain */
#define ERANGE          34              /* Result too large */

/* non-blocking and interrupt i/o */
#define EAGAIN          35              /* Resource temporarily unavailable */
#define EWOULDBLOCK     EAGAIN          /* Operation would block */
#define EINPROGRESS     36              /* Operation now in progress */
#define EALREADY        37              /* Operation already in progress */

/* ipc/network software -- argument errors */
#define ENOTSOCK        38              /* Socket operation on non-socket */
#define EDESTADDRREQ    39              /* Destination address required */
#define EMSGSIZE        40              /* Message too long */
#define EPROTOTYPE      41              /* Protocol wrong type for socket */
#define ENOPROTOOPT     42              /* Protocol not available */
#define EPROTONOSUPPORT 43              /* Protocol not supported */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define ESOCKTNOSUPPORT 44              /* Socket type not supported */
#endif
#define ENOTSUP         45              /* Operation not supported */
#if !__DARWIN_UNIX03 && !defined(KERNEL)
/*
 * This is the same for binary and source copmpatability, unless compiling
 * the kernel itself, or compiling __DARWIN_UNIX03; if compiling for the
 * kernel, the correct value will be returned.  If compiling non-POSIX
 * source, the kernel return value will be converted by a stub in libc, and
 * if compiling source with __DARWIN_UNIX03, the conversion in libc is not
 * done, and the caller gets the expected (discrete) value.
 */
#define EOPNOTSUPP       ENOTSUP        /* Operation not supported on socket */
#endif /* !__DARWIN_UNIX03 && !KERNEL */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define EPFNOSUPPORT    46              /* Protocol family not supported */
#endif
#define EAFNOSUPPORT    47              /* Address family not supported by protocol family */
#define EADDRINUSE      48              /* Address already in use */
#define EADDRNOTAVAIL   49              /* Can't assign requested address */

/* ipc/network software -- operational errors */
#define ENETDOWN        50              /* Network is down */
#define ENETUNREACH     51              /* Network is unreachable */
#define ENETRESET       52              /* Network dropped connection on reset */
#define ECONNABORTED    53              /* Software caused connection abort */
#define ECONNRESET      54              /* Connection reset by peer */
#define ENOBUFS         55              /* No buffer space available */
#define EISCONN         56              /* Socket is already connected */
#define ENOTCONN        57              /* Socket is not connected */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define ESHUTDOWN       58              /* Can't send after socket shutdown */
#define ETOOMANYREFS    59              /* Too many references: can't splice */
#endif
#define ETIMEDOUT       60              /* Operation timed out */
#define ECONNREFUSED    61              /* Connection refused */

#define ELOOP           62              /* Too many levels of symbolic links */
#define ENAMETOOLONG    63              /* File name too long */

/* should be rearranged */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define EHOSTDOWN       64              /* Host is down */
#endif
#define EHOSTUNREACH    65              /* No route to host */
#define ENOTEMPTY       66              /* Directory not empty */

/* quotas & mush */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define EPROCLIM        67              /* Too many processes */
#define EUSERS          68              /* Too many users */
#endif
#define EDQUOT          69              /* Disc quota exceeded */

/* Network File System */
#define ESTALE          70              /* Stale NFS file handle */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define EREMOTE         71              /* Too many levels of remote in path */
#define EBADRPC         72              /* RPC struct is bad */
#define ERPCMISMATCH    73              /* RPC version wrong */
#define EPROGUNAVAIL    74              /* RPC prog. not avail */
#define EPROGMISMATCH   75              /* Program version wrong */
#define EPROCUNAVAIL    76              /* Bad procedure for program */
#endif

#define ENOLCK          77              /* No locks available */
#define ENOSYS          78              /* Function not implemented */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define EFTYPE          79              /* Inappropriate file type or format */
#define EAUTH           80              /* Authentication error */
#define ENEEDAUTH       81              /* Need authenticator */

/* Intelligent device errors */
#define EPWROFF         82      /* Device power is off */
#define EDEVERR         83      /* Device error, e.g. paper out */
#endif

#define EOVERFLOW       84              /* Value too large to be stored in data type */

/* Program loading errors */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define EBADEXEC        85      /* Bad executable */
#define EBADARCH        86      /* Bad CPU type in executable */
#define ESHLIBVERS      87      /* Shared library version mismatch */
#define EBADMACHO       88      /* Malformed Macho file */
#endif

#define ECANCELED       89              /* Operation canceled */

#define EIDRM           90              /* Identifier removed */
#define ENOMSG          91              /* No message of desired type */
#define EILSEQ          92              /* Illegal byte sequence */
#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define ENOATTR         93              /* Attribute not found */
#endif

#define EBADMSG         94              /* Bad message */
#define EMULTIHOP       95              /* Reserved */
#define ENODATA         96              /* No message available on STREAM */
#define ENOLINK         97              /* Reserved */
#define ENOSR           98              /* No STREAM resources */
#define ENOSTR          99              /* Not a STREAM */
#define EPROTO          100             /* Protocol error */
#define ETIME           101             /* STREAM ioctl timeout */

#if __DARWIN_UNIX03 || defined(KERNEL)
/* This value is only discrete when compiling __DARWIN_UNIX03, or KERNEL */
#define EOPNOTSUPP      102             /* Operation not supported on socket */
#endif /* __DARWIN_UNIX03 || KERNEL */

#define ENOPOLICY       103             /* No such policy registered */

#if __DARWIN_C_LEVEL >= 200809L
#define ENOTRECOVERABLE 104             /* State not recoverable */
#define EOWNERDEAD      105             /* Previous owner died */
#endif

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define EQFULL          106             /* Interface output queue is full */
#define ELAST           106             /* Must be equal largest errno */
#endif

#endif /* _SYS_ERRNO_H_ */