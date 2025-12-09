/*-
 * SPDX-License-Identifier: BSD-4-Clause
 *
 * Copyright (c) 1994, Henrik Vestergaard Draboel
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Henrik Vestergaard Draboel.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
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
 */

#ifndef _SYS_PRIORITY_H_
#define _SYS_PRIORITY_H_

/*
 * Process priority specifications.
 */

/*
 * Priority classes.
 */

#define	PRI_ITHD		1	/* Interrupt thread. */
#define	PRI_REALTIME		2	/* Real time process. */
#define	PRI_TIMESHARE		3	/* Time sharing process. */
#define	PRI_IDLE		4	/* Idle process. */

/*
 * PRI_FIFO is POSIX.1B SCHED_FIFO.
 */

#define	PRI_FIFO_BIT		8
#define	PRI_FIFO		(PRI_FIFO_BIT | PRI_REALTIME)

#define	PRI_BASE(P)		((P) & ~PRI_FIFO_BIT)
#define	PRI_IS_REALTIME(P)	(PRI_BASE(P) == PRI_REALTIME)
#define	PRI_NEED_RR(P)		((P) != PRI_FIFO)

/*
 * Priorities.  Note that with 64 run queues, differences less than 4 are
 * insignificant.
 */

/*
 * Priorities range from 0 to 255.  Ranges are as follows:
 *
 * Interrupt threads:		0 - 7
 * Realtime user threads:	8 - 39
 * Top half kernel threads:	40 - 55
 * Time sharing user threads:	56 - 223
 * Idle user threads:		224 - 255
 *
 * Priority levels of rtprio(2)'s RTP_PRIO_FIFO and RTP_PRIO_REALTIME and
 * POSIX's SCHED_FIFO and SCHED_RR are directly mapped to the internal realtime
 * range mentioned above by a simple translation.  This range's length
 * consequently cannot be changed without impacts on the scheduling priority
 * code, and in any case must never be smaller than 32 for POSIX compliance and
 * rtprio(2) backwards compatibility.  Similarly, priority levels of rtprio(2)'s
 * RTP_PRIO_IDLE are directly mapped to the internal idle range above (and,
 * soon, those of the to-be-introduced SCHED_IDLE policy as well), so changing
 * that range is subject to the same caveats and restrictions.
 */

#define	PRI_MIN			(0)		/* Highest priority. */
#define	PRI_MAX			(255)		/* Lowest priority. */

#define	PRI_MIN_ITHD		(PRI_MIN)
#define	PRI_MAX_ITHD		(PRI_MIN_REALTIME - 1)

/*
 * Most hardware interrupt threads run at the same priority, but can
 * decay to lower priorities if they run for full time slices.
 */
#define	PI_REALTIME		(PRI_MIN_ITHD + 0)
#define	PI_INTR			(PRI_MIN_ITHD + 1)
#define	PI_AV			PI_INTR
#define	PI_NET			PI_INTR
#define	PI_DISK			PI_INTR
#define	PI_TTY			PI_INTR
#define	PI_DULL			PI_INTR
#define	PI_SOFT			(PRI_MIN_ITHD + 2)
#define	PI_SOFTCLOCK		PI_SOFT
#define	PI_SWI(x)		PI_SOFT

#define	PRI_MIN_REALTIME	(8)
#define	PRI_MAX_REALTIME	(PRI_MIN_KERN - 1)

#define	PRI_MIN_KERN		(40)
#define	PRI_MAX_KERN		(PRI_MIN_TIMESHARE - 1)

#define	PSWP			(PRI_MIN_KERN + 0)
#define	PVM			(PRI_MIN_KERN + 1)
#define	PINOD			(PRI_MIN_KERN + 2)
#define	PRIBIO			(PRI_MIN_KERN + 3)
#define	PVFS			(PRI_MIN_KERN + 4)
#define	PZERO			(PRI_MIN_KERN + 5)
#define	PSOCK			(PRI_MIN_KERN + 6)
#define	PWAIT			(PRI_MIN_KERN + 7)
#define	PLOCK			(PRI_MIN_KERN + 8)
#define	PPAUSE			(PRI_MIN_KERN + 9)

#define	PRI_MIN_TIMESHARE	(56)
#define	PRI_MAX_TIMESHARE	(PRI_MIN_IDLE - 1)

#define	PUSER			(PRI_MIN_TIMESHARE)

#define	PRI_MIN_IDLE		(224)
#define	PRI_MAX_IDLE		(PRI_MAX)

#ifdef _KERNEL
/* Other arguments for kern_yield(9). */
#define	PRI_USER	-2	/* Change to current user priority. */
#define	PRI_UNCHANGED	-1	/* Do not change priority. */
#endif

struct priority {
	u_char	pri_class;	/* Scheduling class. */
	u_char	pri_level;	/* Normal priority level. */
	u_char	pri_native;	/* Priority before propagation. */
	u_char	pri_user;	/* User priority based on p_cpu and p_nice. */
};

#endif	/* !_SYS_PRIORITY_H_ */