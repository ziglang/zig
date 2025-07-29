/*	$NetBSD: timepps.h,v 1.22 2016/07/07 06:55:44 msaitoh Exp $	*/

/*
 * Copyright (c) 1998 Jonathan Stone
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
 *      This product includes software developed by Jonathan Stone for
 *      the NetBSD Project.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_TIMEPPS_H_
#define _SYS_TIMEPPS_H_

/*
 * This header file complies with "Pulse-Per-Second API for UNIX-like
 * Operating Systems, Version 1.0", draft-mogul-pps-api-05.txt
 */

#include <sys/ioccom.h>

#define PPS_API_VERS_1	1	/* API version number */

/*
 * PPSAPI type definitions
 */
typedef int32_t pps_handle_t;	/* represents a PPS source */
typedef uint32_t pps_seq_t;	/* sequence number, at least 32 bits */

typedef union pps_timeu {
	struct timespec	tspec;
	struct {        /* NTP long fixed-point format */
		unsigned int     integral;
		unsigned int     fractional;
	} ntplfp;
	unsigned long   longpair[2];
} pps_timeu_t;


/*
 * timestamp information
 */
typedef struct {
	pps_seq_t	assert_sequence;	/* assert event seq # */
	pps_seq_t	clear_sequence;		/* clear event seq # */
	pps_timeu_t	assert_tu;
	pps_timeu_t	clear_tu;
	int		current_mode;		/* current mode bits */
} pps_info_t;

#define assert_timestamp	assert_tu.tspec
#define clear_timestamp		clear_tu.tspec


/*
 * Parameter structure
 */
typedef struct {
	int api_version;			/* API version number */
	int mode;				/* mode bits */
	pps_timeu_t	assert_off_tu;
	pps_timeu_t	clear_off_tu;
} pps_params_t;
#define assert_offset		assert_off_tu.tspec
#define clear_offset		clear_off_tu.tspec


/*
 * Device/implementation parameters (mode, edge bits)
 */
#define PPS_CAPTUREASSERT	0x01
#define PPS_CAPTURECLEAR	0x02
#define PPS_CAPTUREBOTH		0x03
#define PPS_OFFSETASSERT	0x10
#define PPS_OFFSETCLEAR		0x20
#define PPS_CANWAIT		0x100
#define PPS_CANPOLL		0x200

/*
 * Kernel actions
 */
#define PPS_ECHOASSERT		0x40
#define PPS_ECHOCLEAR		0x80


/*
 * timestamp formats (tsformat, mode)
 */
#define PPS_TSFMT_TSPEC		0x1000
#define PPS_TSFMT_NTPLFP	0x2000

/*
 * Kernel discipline actions (kernel_consumer)
 */
#define PPS_KC_HARDPPS		0
#define PPS_KC_HARDPPS_PLL	1
#define PPS_KC_HARDPPS_FLL	2

/*
 * IOCTL definitions
 */
#define PPS_IOC_CREATE		_IO('1', 1)
#define PPS_IOC_DESTROY		_IO('1', 2)
#define PPS_IOC_SETPARAMS	_IOW('1', 3, pps_params_t)
#define PPS_IOC_GETPARAMS	_IOR('1', 4, pps_params_t)
#define PPS_IOC_GETCAP		_IOR('1', 5, int)
#define PPS_IOC_FETCH		_IOWR('1', 6, pps_info_t)
#define PPS_IOC_KCBIND		_IOW('1', 7, int)

#ifdef _KERNEL

#include <sys/mutex.h>

/* flags for pps_ref_event() - bitmask but only 1 bit allowed */
#define PPS_REFEVNT_CAPTURE	0x01 /* use captume time stamp */
#define PPS_REFEVNT_CURRENT	0x02 /* use current time stamp */
#define PPS_REFEVNT_CAPCUR	0x04 /* use average of above */
#define PPS_REFEVNT_RMASK       0x0F /* mask reference bits */

#define PPS_REFEVNT_PPS		0x10 /* guess PPS second from */
                                     /* capture timestamp */

extern kmutex_t timecounter_lock;

struct pps_state {
	/* Capture information. */
	struct timehands *capth;
	unsigned	capgen;
	u_int64_t	capcount;
	struct bintime  ref_time;

	/* State information. */
	pps_params_t	ppsparam;
	pps_info_t	ppsinfo;
	int		kcmode;
	int		ppscap;
	struct timecounter *ppstc;
	u_int64_t	ppscount[3];
};

void pps_capture(struct pps_state *);
void pps_event(struct pps_state *, int);
void pps_ref_event(struct pps_state *, int, struct bintime *, int);
void pps_init(struct pps_state *);
int pps_ioctl(unsigned long, void *, struct pps_state *);

#else /* !_KERNEL */

#include <sys/cdefs.h>
#include <sys/ioctl.h>
#include <errno.h>

static __inline int time_pps_create(int, pps_handle_t *);
static __inline int time_pps_destroy(pps_handle_t);
static __inline int time_pps_setparams(pps_handle_t, const pps_params_t *);
static __inline int time_pps_getparams(pps_handle_t, pps_params_t *);
static __inline int time_pps_getcap(pps_handle_t, int *);
static __inline int time_pps_fetch(pps_handle_t, const int, pps_info_t *,
	const struct timespec *);
#if 0
static __inline int time_pps_wait(pps_handle_t, const struct timespec *,
	pps_info_t *);
#endif

static __inline int time_pps_kcbind(pps_handle_t, const int, const int,
	const int);

static __inline int
time_pps_create(int filedes, pps_handle_t *handle)
{

	*handle = filedes;
	return (0);
}

static __inline int
time_pps_destroy(pps_handle_t handle)
{

	return (0);
}

static __inline int
time_pps_setparams(pps_handle_t handle, const pps_params_t *ppsparams)
{

	return (ioctl(handle, PPS_IOC_SETPARAMS, __UNCONST(ppsparams)));
}

static __inline int
time_pps_getparams(pps_handle_t handle, pps_params_t *ppsparams)
{

	return (ioctl(handle, PPS_IOC_GETPARAMS, ppsparams));
}

static __inline int
time_pps_getcap(pps_handle_t handle, int *mode)
{

	return (ioctl(handle, PPS_IOC_GETCAP, mode));
}

static __inline int
time_pps_fetch(pps_handle_t handle, const int tsformat, pps_info_t *ppsinfobuf,
	const struct timespec *timeout)
{

	return (ioctl(handle, PPS_IOC_FETCH, ppsinfobuf));
}

static __inline int
time_pps_kcbind(pps_handle_t handle, const int kernel_consumer, const int edge,
	const int tsformat)
{

	if (tsformat != PPS_TSFMT_TSPEC) {
		errno = EINVAL;
		return -1;
	}

	return (ioctl(handle, PPS_IOC_KCBIND, __UNCONST(&edge)));
}
#endif /* !_KERNEL*/
#endif /* SYS_TIMEPPS_H_ */