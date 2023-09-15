/*
 * Copyright (c) 2003-2021 Apple Inc. All rights reserved.
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
/*-
 * Copyright (c) 1999,2000,2001 Jonathan Lemon <jlemon@FreeBSD.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	$FreeBSD: src/sys/sys/event.h,v 1.5.2.5 2001/12/14 19:21:22 jlemon Exp $
 */

#ifndef _SYS_EVENT_H_
#define _SYS_EVENT_H_

#include <machine/types.h>
#include <sys/cdefs.h>
#include <sys/queue.h>
#include <stdint.h>
#include <sys/types.h>

/*
 * Filter types
 */
#define EVFILT_READ             (-1)
#define EVFILT_WRITE            (-2)
#define EVFILT_AIO              (-3)    /* attached to aio requests */
#define EVFILT_VNODE            (-4)    /* attached to vnodes */
#define EVFILT_PROC             (-5)    /* attached to struct proc */
#define EVFILT_SIGNAL           (-6)    /* attached to struct proc */
#define EVFILT_TIMER            (-7)    /* timers */
#define EVFILT_MACHPORT         (-8)    /* Mach portsets */
#define EVFILT_FS               (-9)    /* Filesystem events */
#define EVFILT_USER             (-10)   /* User events */
#define EVFILT_VM               (-12)   /* Virtual memory events */
#define EVFILT_EXCEPT           (-15)   /* Exception events */

#define EVFILT_SYSCOUNT         17
#define EVFILT_THREADMARKER     EVFILT_SYSCOUNT /* Internal use only */

#pragma pack(4)

struct kevent {
	uintptr_t       ident;  /* identifier for this event */
	int16_t         filter; /* filter for event */
	uint16_t        flags;  /* general flags */
	uint32_t        fflags; /* filter-specific flags */
	intptr_t        data;   /* filter-specific data */
	void            *udata; /* opaque user data identifier */
};

#pragma pack()

struct kevent64_s {
	uint64_t        ident;          /* identifier for this event */
	int16_t         filter;         /* filter for event */
	uint16_t        flags;          /* general flags */
	uint32_t        fflags;         /* filter-specific flags */
	int64_t         data;           /* filter-specific data */
	uint64_t        udata;          /* opaque user data identifier */
	uint64_t        ext[2];         /* filter-specific extensions */
};

#define EV_SET(kevp, a, b, c, d, e, f) do {     \
	struct kevent *__kevp__ = (kevp);       \
	__kevp__->ident = (a);                  \
	__kevp__->filter = (b);                 \
	__kevp__->flags = (c);                  \
	__kevp__->fflags = (d);                 \
	__kevp__->data = (e);                   \
	__kevp__->udata = (f);                  \
} while(0)

#define EV_SET64(kevp, a, b, c, d, e, f, g, h) do {     \
	struct kevent64_s *__kevp__ = (kevp);           \
	__kevp__->ident = (a);                          \
	__kevp__->filter = (b);                         \
	__kevp__->flags = (c);                          \
	__kevp__->fflags = (d);                         \
	__kevp__->data = (e);                           \
	__kevp__->udata = (f);                          \
	__kevp__->ext[0] = (g);                         \
	__kevp__->ext[1] = (h);                         \
} while(0)


/* kevent system call flags */
#define KEVENT_FLAG_NONE                         0x000000       /* no flag value */
#define KEVENT_FLAG_IMMEDIATE                    0x000001       /* immediate timeout */
#define KEVENT_FLAG_ERROR_EVENTS                 0x000002       /* output events only include change errors */

/* actions */
#define EV_ADD              0x0001      /* add event to kq (implies enable) */
#define EV_DELETE           0x0002      /* delete event from kq */
#define EV_ENABLE           0x0004      /* enable event */
#define EV_DISABLE          0x0008      /* disable event (not reported) */

/* flags */
#define EV_ONESHOT          0x0010      /* only report one occurrence */
#define EV_CLEAR            0x0020      /* clear event state after reporting */
#define EV_RECEIPT          0x0040      /* force immediate event output */
                                        /* ... with or without EV_ERROR */
                                        /* ... use KEVENT_FLAG_ERROR_EVENTS */
                                        /*     on syscalls supporting flags */

#define EV_DISPATCH         0x0080      /* disable event after reporting */
#define EV_UDATA_SPECIFIC   0x0100      /* unique kevent per udata value */

#define EV_DISPATCH2        (EV_DISPATCH | EV_UDATA_SPECIFIC)
/* ... in combination with EV_DELETE */
/* will defer delete until udata-specific */
/* event enabled. EINPROGRESS will be */
/* returned to indicate the deferral */

#define EV_VANISHED         0x0200      /* report that source has vanished  */
                                        /* ... only valid with EV_DISPATCH2 */

#define EV_SYSFLAGS         0xF000      /* reserved by system */
#define EV_FLAG0            0x1000      /* filter-specific flag */
#define EV_FLAG1            0x2000      /* filter-specific flag */

/* returned values */
#define EV_EOF              0x8000      /* EOF detected */
#define EV_ERROR            0x4000      /* error, data contains errno */

/*
 * Filter specific flags for EVFILT_READ
 *
 * The default behavior for EVFILT_READ is to make the "read" determination
 * relative to the current file descriptor read pointer.
 *
 * The EV_POLL flag indicates the determination should be made via poll(2)
 * semantics. These semantics dictate always returning true for regular files,
 * regardless of the amount of unread data in the file.
 *
 * On input, EV_OOBAND specifies that filter should actively return in the
 * presence of OOB on the descriptor. It implies that filter will return
 * if there is OOB data available to read OR when any other condition
 * for the read are met (for example number of bytes regular data becomes >=
 * low-watermark).
 * If EV_OOBAND is not set on input, it implies that the filter should not actively
 * return for out of band data on the descriptor. The filter will then only return
 * when some other condition for read is met (ex: when number of regular data bytes
 * >=low-watermark OR when socket can't receive more data (SS_CANTRCVMORE)).
 *
 * On output, EV_OOBAND indicates the presence of OOB data on the descriptor.
 * If it was not specified as an input parameter, then the data count is the
 * number of bytes before the current OOB marker, else data count is the number
 * of bytes beyond OOB marker.
 */
#define EV_POLL         EV_FLAG0
#define EV_OOBAND       EV_FLAG1

/*
 * data/hint fflags for EVFILT_USER, shared with userspace
 */

/*
 * On input, NOTE_TRIGGER causes the event to be triggered for output.
 */
#define NOTE_TRIGGER    0x01000000

/*
 * On input, the top two bits of fflags specifies how the lower twenty four
 * bits should be applied to the stored value of fflags.
 *
 * On output, the top two bits will always be set to NOTE_FFNOP and the
 * remaining twenty four bits will contain the stored fflags value.
 */
#define NOTE_FFNOP      0x00000000              /* ignore input fflags */
#define NOTE_FFAND      0x40000000              /* and fflags */
#define NOTE_FFOR       0x80000000              /* or fflags */
#define NOTE_FFCOPY     0xc0000000              /* copy fflags */
#define NOTE_FFCTRLMASK 0xc0000000              /* mask for operations */
#define NOTE_FFLAGSMASK 0x00ffffff

/*
 * data/hint fflags for EVFILT_{READ|WRITE}, shared with userspace
 *
 * The default behavior for EVFILT_READ is to make the determination
 * realtive to the current file descriptor read pointer.
 */
#define NOTE_LOWAT      0x00000001              /* low water mark */

/* data/hint flags for EVFILT_EXCEPT, shared with userspace */
#define NOTE_OOB        0x00000002              /* OOB data */

/*
 * data/hint fflags for EVFILT_VNODE, shared with userspace
 */
#define NOTE_DELETE     0x00000001              /* vnode was removed */
#define NOTE_WRITE      0x00000002              /* data contents changed */
#define NOTE_EXTEND     0x00000004              /* size increased */
#define NOTE_ATTRIB     0x00000008              /* attributes changed */
#define NOTE_LINK       0x00000010              /* link count changed */
#define NOTE_RENAME     0x00000020              /* vnode was renamed */
#define NOTE_REVOKE     0x00000040              /* vnode access was revoked */
#define NOTE_NONE       0x00000080              /* No specific vnode event: to test for EVFILT_READ activation*/
#define NOTE_FUNLOCK    0x00000100              /* vnode was unlocked by flock(2) */
#define NOTE_LEASE_DOWNGRADE 0x00000200         /* lease downgrade requested */
#define NOTE_LEASE_RELEASE 0x00000400           /* lease release requested */

/*
 * data/hint fflags for EVFILT_PROC, shared with userspace
 *
 * Please note that EVFILT_PROC and EVFILT_SIGNAL share the same knote list
 * that hangs off the proc structure. They also both play games with the hint
 * passed to KNOTE(). If NOTE_SIGNAL is passed as a hint, then the lower bits
 * of the hint contain the signal. IF NOTE_FORK is passed, then the lower bits
 * contain the PID of the child (but the pid does not get passed through in
 * the actual kevent).
 */
enum {
	eNoteReapDeprecated __deprecated_enum_msg("This kqueue(2) EVFILT_PROC flag is deprecated") = 0x10000000
};

#define NOTE_EXIT               0x80000000      /* process exited */
#define NOTE_FORK               0x40000000      /* process forked */
#define NOTE_EXEC               0x20000000      /* process exec'd */
#define NOTE_REAP               ((unsigned int)eNoteReapDeprecated /* 0x10000000 */ )   /* process reaped */
#define NOTE_SIGNAL             0x08000000      /* shared with EVFILT_SIGNAL */
#define NOTE_EXITSTATUS         0x04000000      /* exit status to be returned, valid for child process or when allowed to signal target pid */
#define NOTE_EXIT_DETAIL        0x02000000      /* provide details on reasons for exit */

#define NOTE_PDATAMASK  0x000fffff              /* mask for signal & exit status */
#define NOTE_PCTRLMASK  (~NOTE_PDATAMASK)

/*
 * If NOTE_EXITSTATUS is present, provide additional info about exiting process.
 */
enum {
	eNoteExitReparentedDeprecated __deprecated_enum_msg("This kqueue(2) EVFILT_PROC flag is no longer sent") = 0x00080000
};
#define NOTE_EXIT_REPARENTED    ((unsigned int)eNoteExitReparentedDeprecated)   /* exited while reparented */

/*
 * If NOTE_EXIT_DETAIL is present, these bits indicate specific reasons for exiting.
 */
#define NOTE_EXIT_DETAIL_MASK           0x00070000
#define NOTE_EXIT_DECRYPTFAIL           0x00010000
#define NOTE_EXIT_MEMORY                0x00020000
#define NOTE_EXIT_CSERROR               0x00040000

/*
 * data/hint fflags for EVFILT_VM, shared with userspace.
 */
#define NOTE_VM_PRESSURE                        0x80000000              /* will react on memory pressure */
#define NOTE_VM_PRESSURE_TERMINATE              0x40000000              /* will quit on memory pressure, possibly after cleaning up dirty state */
#define NOTE_VM_PRESSURE_SUDDEN_TERMINATE       0x20000000              /* will quit immediately on memory pressure */
#define NOTE_VM_ERROR                           0x10000000              /* there was an error */

/*
 * data/hint fflags for EVFILT_TIMER, shared with userspace.
 * The default is a (repeating) interval timer with the data
 * specifying the timeout interval in milliseconds.
 *
 * All timeouts are implicitly EV_CLEAR events.
 */
#define NOTE_SECONDS    0x00000001              /* data is seconds         */
#define NOTE_USECONDS   0x00000002              /* data is microseconds    */
#define NOTE_NSECONDS   0x00000004              /* data is nanoseconds     */
#define NOTE_ABSOLUTE   0x00000008              /* absolute timeout        */
/* ... implicit EV_ONESHOT, timeout uses the gettimeofday epoch */
#define NOTE_LEEWAY             0x00000010              /* ext[1] holds leeway for power aware timers */
#define NOTE_CRITICAL   0x00000020              /* system does minimal timer coalescing */
#define NOTE_BACKGROUND 0x00000040              /* system does maximum timer coalescing */
#define NOTE_MACH_CONTINUOUS_TIME       0x00000080
/*
 * NOTE_MACH_CONTINUOUS_TIME:
 * with NOTE_ABSOLUTE: causes the timer to continue to tick across sleep,
 *      still uses gettimeofday epoch
 * with NOTE_MACHTIME and NOTE_ABSOLUTE: uses mach continuous time epoch
 * without NOTE_ABSOLUTE (interval timer mode): continues to tick across sleep
 */
#define NOTE_MACHTIME   0x00000100              /* data is mach absolute time units */
/* timeout uses the mach absolute time epoch */

/*
 * data/hint fflags for EVFILT_MACHPORT, shared with userspace.
 *
 * Only portsets are supported at this time.
 *
 * The fflags field can optionally contain the MACH_RCV_MSG, MACH_RCV_LARGE,
 * and related trailer receive options as defined in <mach/message.h>.
 * The presence of these flags directs the kevent64() call to attempt to receive
 * the message during kevent delivery, rather than just indicate that a message exists.
 * On setup, The ext[0] field contains the receive buffer pointer and ext[1] contains
 * the receive buffer length.  Upon event delivery, the actual received message size
 * is returned in ext[1].  As with mach_msg(), the buffer must be large enough to
 * receive the message and the requested (or default) message trailers.  In addition,
 * the fflags field contains the return code normally returned by mach_msg().
 *
 * If MACH_RCV_MSG is specified, and the ext[1] field specifies a zero length, the
 * system call argument specifying an ouput area (kevent_qos) will be consulted. If
 * the system call specified an output data area, the user-space address
 * of the received message is carved from that provided output data area (if enough
 * space remains there). The address and length of each received message is
 * returned in the ext[0] and ext[1] fields (respectively) of the corresponding kevent.
 *
 * IF_MACH_RCV_VOUCHER_CONTENT is specified, the contents of the message voucher is
 * extracted (as specified in the xflags field) and stored in ext[2] up to ext[3]
 * length.  If the input length is zero, and the system call provided a data area,
 * the space for the voucher content is carved from the provided space and its
 * address and length is returned in ext[2] and ext[3] respectively.
 *
 * If no message receipt options were provided in the fflags field on setup, no
 * message is received by this call. Instead, on output, the data field simply
 * contains the name of the actual port detected with a message waiting.
 */

/*
 * DEPRECATED!!!!!!!!!
 * NOTE_TRACK, NOTE_TRACKERR, and NOTE_CHILD are no longer supported as of 10.5
 */
/* additional flags for EVFILT_PROC */
#define NOTE_TRACK      0x00000001              /* follow across forks */
#define NOTE_TRACKERR   0x00000002              /* could not track child */
#define NOTE_CHILD      0x00000004              /* am a child process */


/* Temporary solution for BootX to use inode.h till kqueue moves to vfs layer */
struct knote;
SLIST_HEAD(klist, knote);

struct timespec;

__BEGIN_DECLS
int     kqueue(void);
int     kevent(int kq,
    const struct kevent *changelist, int nchanges,
    struct kevent *eventlist, int nevents,
    const struct timespec *timeout);
int     kevent64(int kq,
    const struct kevent64_s *changelist, int nchanges,
    struct kevent64_s *eventlist, int nevents,
    unsigned int flags,
    const struct timespec *timeout);

__END_DECLS




#endif /* !_SYS_EVENT_H_ */
