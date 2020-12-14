/*
 * Copyright (c) 2000-2007 Apple Inc. All rights reserved.
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
/*	$NetBSD: msg.h,v 1.4 1994/06/29 06:44:43 cgd Exp $	*/

/*
 * SVID compatible msg.h file
 *
 * Author:  Daniel Boulet
 *
 * Copyright 1993 Daniel Boulet and RTMX Inc.
 *
 * This system call was implemented by Daniel Boulet under contract from RTMX.
 *
 * Redistribution and use in source forms, with and without modification,
 * are permitted provided that this entire comment appears intact.
 *
 * Redistribution in binary form may occur without any restrictions.
 * Obviously, it would be nice if you gave credit where credit is due
 * but requiring it would be too onerous.
 *
 * This software is provided ``AS IS'' without any warranties of any kind.
 */
/*
 * NOTICE: This file was modified by SPARTA, Inc. in 2005 to introduce
 * support for mandatory and extensible security protections.  This notice
 * is included in support of clause 2.2 (b) of the Apple Public License,
 * Version 2.0.
 */

#ifndef _SYS_MSG_H_
#define _SYS_MSG_H_

#include <sys/appleapiopts.h>

#include <sys/_types.h>
#include <sys/cdefs.h>

/*
 * [XSI] All of the symbols from <sys/ipc.h> SHALL be defined when this
 * header is included
 */
#include <sys/ipc.h>


/*
 * [XSI] The pid_t, time_t, key_t, size_t, and ssize_t types shall be
 * defined as described in <sys/types.h>.
 *
 * NOTE:	The definition of the key_t type is implicit from the
 *		inclusion of <sys/ipc.h>
 */
#include <sys/_types/_pid_t.h>
#include <sys/_types/_time_t.h>
#include <sys/_types/_size_t.h>
#include <sys/_types/_ssize_t.h>

/* [XSI] Used for the number of messages in the message queue */
typedef unsigned long           msgqnum_t;

/* [XSI] Used for the number of bytes allowed in a message queue */
typedef unsigned long           msglen_t;

/*
 * Possible values for the fifth parameter to msgrcv(), in addition to the
 * IPC_NOWAIT flag, which is permitted.
 */
#define MSG_NOERROR     010000          /* [XSI] No error if big message */


/*
 * Technically, we should force all code references to the new structure
 * definition, not in just the standards conformance case, and leave the
 * legacy interface there for binary compatibility only.  Currently, we
 * are only forcing this for programs requesting standards conformance.
 */
#if __DARWIN_UNIX03 || defined(KERNEL)
#pragma pack(4)
/*
 * Structure used internally.
 *
 * Structure whose address is passed as the third parameter to msgctl()
 * when the second parameter is IPC_SET or IPC_STAT.  In the case of the
 * IPC_SET command, only the msg_perm.{uid|gid|perm} and msg_qbytes are
 * honored.  In the case of IPC_STAT, only the fields indicated as [XSI]
 * mandated fields are guaranteed to meaningful: DO NOT depend on the
 * contents of the other fields.
 *
 * NOTES:	Reserved fields are not preserved across IPC_SET/IPC_STAT.
 */
#if (defined(_POSIX_C_SOURCE) && !defined(_DARWIN_C_SOURCE))
struct msqid_ds
#else
#define msqid_ds        __msqid_ds_new
struct __msqid_ds_new
#endif
{
	struct __ipc_perm_new   msg_perm; /* [XSI] msg queue permissions */
	__int32_t       msg_first;      /* RESERVED: kernel use only */
	__int32_t       msg_last;       /* RESERVED: kernel use only */
	msglen_t        msg_cbytes;     /* # of bytes on the queue */
	msgqnum_t       msg_qnum;       /* [XSI] number of msgs on the queue */
	msglen_t        msg_qbytes;     /* [XSI] max bytes on the queue */
	pid_t           msg_lspid;      /* [XSI] pid of last msgsnd() */
	pid_t           msg_lrpid;      /* [XSI] pid of last msgrcv() */
	time_t          msg_stime;      /* [XSI] time of last msgsnd() */
	__int32_t       msg_pad1;       /* RESERVED: DO NOT USE */
	time_t          msg_rtime;      /* [XSI] time of last msgrcv() */
	__int32_t       msg_pad2;       /* RESERVED: DO NOT USE */
	time_t          msg_ctime;      /* [XSI] time of last msgctl() */
	__int32_t       msg_pad3;       /* RESERVED: DO NOT USE */
	__int32_t       msg_pad4[4];    /* RESERVED: DO NOT USE */
};
#pragma pack()
#else   /* !__DARWIN_UNIX03 */
#define msqid_ds        __msqid_ds_old
#endif  /* !__DARWIN_UNIX03 */

#if !__DARWIN_UNIX03
struct __msqid_ds_old {
	struct __ipc_perm_old   msg_perm; /* [XSI] msg queue permissions */
	__int32_t       msg_first;      /* RESERVED: kernel use only */
	__int32_t       msg_last;       /* RESERVED: kernel use only */
	msglen_t        msg_cbytes;     /* # of bytes on the queue */
	msgqnum_t       msg_qnum;       /* [XSI] number of msgs on the queue */
	msglen_t        msg_qbytes;     /* [XSI] max bytes on the queue */
	pid_t           msg_lspid;      /* [XSI] pid of last msgsnd() */
	pid_t           msg_lrpid;      /* [XSI] pid of last msgrcv() */
	time_t          msg_stime;      /* [XSI] time of last msgsnd() */
	__int32_t       msg_pad1;       /* RESERVED: DO NOT USE */
	time_t          msg_rtime;      /* [XSI] time of last msgrcv() */
	__int32_t       msg_pad2;       /* RESERVED: DO NOT USE */
	time_t          msg_ctime;      /* [XSI] time of last msgctl() */
	__int32_t       msg_pad3;       /* RESERVED: DO NOT USE */
	__int32_t       msg_pad4[4];    /* RESERVED: DO NOT USE */
};
#endif  /* !__DARWIN_UNIX03 */



#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#ifdef __APPLE_API_UNSTABLE
/* XXX kernel only; protect with macro later */

struct msg {
	struct msg      *msg_next;      /* next msg in the chain */
	long            msg_type;       /* type of this message */
	                                /* >0 -> type of this message */
	                                /* 0 -> free header */
	unsigned short  msg_ts;         /* size of this message */
	short           msg_spot;       /* location of msg start in buffer */
	struct label    *label;         /* MAC label */
};

/*
 * Example structure describing a message whose address is to be passed as
 * the second argument to the functions msgrcv() and msgsnd().  The only
 * actual hard requirement is that the first field be of type long, and
 * contain the message type.  The user is encouraged to define their own
 * application specific structure; this definition is included solely for
 * backward compatability with existing source code.
 */
struct mymsg {
	long    mtype;          /* message type (+ve integer) */
	char    mtext[1];       /* message body */
};

/*
 * Based on the configuration parameters described in an SVR2 (yes, two)
 * config(1m) man page.
 *
 * Each message is broken up and stored in segments that are msgssz bytes
 * long.  For efficiency reasons, this should be a power of two.  Also,
 * it doesn't make sense if it is less than 8 or greater than about 256.
 * Consequently, msginit in kern/sysv_msg.c checks that msgssz is a power of
 * two between 8 and 1024 inclusive (and panic's if it isn't).
 */
struct msginfo {
	int     msgmax,         /* max chars in a message */
	    msgmni,             /* max message queue identifiers */
	    msgmnb,             /* max chars in a queue */
	    msgtql,             /* max messages in system */
	    msgssz,             /* size of a message segment (see notes above) */
	    msgseg;             /* number of message segments */
};
#endif  /* __APPLE_API_UNSTABLE */
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */


__BEGIN_DECLS
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
int msgsys(int, ...);
#endif  /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
int msgctl(int, int, struct msqid_ds *) __DARWIN_ALIAS(msgctl);
int msgget(key_t, int);
ssize_t msgrcv(int, void *, size_t, long, int) __DARWIN_ALIAS_C(msgrcv);
int msgsnd(int, const void *, size_t, int) __DARWIN_ALIAS_C(msgsnd);
__END_DECLS


#endif /* !_SYS_MSG_H_ */