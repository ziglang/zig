/*	$NetBSD: timex.h,v 1.20 2022/10/26 23:23:52 riastradh Exp $	*/

/*-
 ***********************************************************************
 *								       *
 * Copyright (c) David L. Mills 1993-2001			       *
 *								       *
 * Permission to use, copy, modify, and distribute this software and   *
 * its documentation for any purpose and without fee is hereby	       *
 * granted, provided that the above copyright notice appears in all    *
 * copies and that both the copyright notice and this permission       *
 * notice appear in supporting documentation, and that the name        *
 * University of Delaware not be used in advertising or publicity      *
 * pertaining to distribution of the software without specific,	       *
 * written prior permission. The University of Delaware makes no       *
 * representations about the suitability this software for any	       *
 * purpose. It is provided "as is" without express or implied	       *
 * warranty.							       *
 *								       *
 **********************************************************************/

/*
 * Modification history timex.h
 *
 * 16 Aug 00	David L. Mills
 *	API Version 4. Added MOD_TAI and tai member of ntptimeval
 *	structure.
 *
 * 17 Nov 98	David L. Mills
 *	Revised for nanosecond kernel and user interface.
 *
 * 26 Sep 94	David L. Mills
 *	Added defines for hybrid phase/frequency-lock loop.
 *
 * 19 Mar 94	David L. Mills
 *	Moved defines from kernel routines to header file and added new
 *	defines for PPS phase-lock loop.
 *
 * 20 Feb 94	David L. Mills
 *	Revised status codes and structures for external clock and PPS
 *	signal discipline.
 *
 * 28 Nov 93	David L. Mills
 *	Adjusted parameters to improve stability and increase poll
 *	interval.
 *
 * 17 Sep 93    David L. Mills
 *      Created file
 *
 * $FreeBSD: src/sys/sys/timex.h,v 1.18 2005/01/07 02:29:24 imp Exp $
 */
/*
 * This header file defines the Network Time Protocol (NTP) interfaces
 * for user and daemon application programs. These are implemented using
 * defined syscalls and data structures and require specific kernel
 * support.
 *
 * The original precision time kernels developed from 1993 have an
 * ultimate resolution of one microsecond; however, the most recent
 * kernels have an ultimate resolution of one nanosecond. In these
 * kernels, a ntp_adjtime() syscalls can be used to determine which
 * resolution is in use and to select either one at any time. The
 * resolution selected affects the scaling of certain fields in the
 * ntp_gettime() and ntp_adjtime() syscalls, as described below.
 *
 * NAME
 *	ntp_gettime - NTP user application interface
 *
 * SYNOPSIS
 *	#include <sys/timex.h>
 *
 *	int ntp_gettime(struct ntptimeval *ntv);
 *
 * DESCRIPTION
 *	The time returned by ntp_gettime() is in a timespec structure,
 *	but may be in either microsecond (seconds and microseconds) or
 *	nanosecond (seconds and nanoseconds) format. The particular
 *	format in use is determined by the STA_NANO bit of the status
 *	word returned by the ntp_adjtime() syscall.
 *
 * NAME
 *	ntp_adjtime - NTP daemon application interface
 *
 * SYNOPSIS
 *	#include <sys/timex.h>
 *	#include <sys/syscall.h>
 *
 *	int syscall(SYS_ntp_adjtime, tptr);
 *	int SYS_ntp_adjtime;
 *	struct timex *tptr;
 *
 * DESCRIPTION
 *	Certain fields of the timex structure are interpreted in either
 *	microseconds or nanoseconds according to the state of the
 *	STA_NANO bit in the status word. See the description below for
 *	further information.
 */

#ifndef _SYS_TIMEX_H_
#define _SYS_TIMEX_H_ 1
#define NTP_API		4	/* NTP API version */

#include <sys/syscall.h>

/*
 * The following defines establish the performance envelope of the
 * kernel discipline loop. Phase or frequency errors greater than
 * NAXPHASE or MAXFREQ are clamped to these maxima. For update intervals
 * less than MINSEC, the loop always operates in PLL mode; while, for
 * update intervals greater than MAXSEC, the loop always operates in FLL
 * mode. Between these two limits the operating mode is selected by the
 * STA_FLL bit in the status word.
 */
#define MAXPHASE	500000000L /* max phase error (ns) */
#define MAXFREQ		500000L	/* max freq error (ns/s) */
#define MINSEC		256	/* min FLL update interval (s) */
#define MAXSEC		2048	/* max PLL update interval (s) */
#define NANOSECOND	1000000000L /* nanoseconds in one second */
#define SCALE_PPM	(65536 / 1000) /* crude ns/s to scaled PPM */
#define MAXTC		10	/* max time constant */

/*
 * The following defines and structures define the user interface for
 * the ntp_gettime() and ntp_adjtime() syscalls.
 *
 * Control mode codes (timex.modes)
 */
#define MOD_OFFSET	0x0001	/* set time offset */
#define MOD_FREQUENCY	0x0002	/* set frequency offset */
#define MOD_MAXERROR	0x0004	/* set maximum time error */
#define MOD_ESTERROR	0x0008	/* set estimated time error */
#define MOD_STATUS	0x0010	/* set clock status bits */
#define MOD_TIMECONST	0x0020	/* set PLL time constant */
#define MOD_PPSMAX	0x0040	/* set PPS maximum averaging time */
#define MOD_TAI		0x0080	/* set TAI offset */
#define	MOD_MICRO	0x1000	/* select microsecond resolution */
#define	MOD_NANO	0x2000	/* select nanosecond resolution */
#define MOD_CLKB	0x4000	/* select clock B */
#define MOD_CLKA	0x8000	/* select clock A */

/*
 * Status codes (timex.status)
 */
#define STA_PLL		0x0001	/* enable PLL updates (rw) */
#define STA_PPSFREQ	0x0002	/* enable PPS freq discipline (rw) */
#define STA_PPSTIME	0x0004	/* enable PPS time discipline (rw) */
#define STA_FLL		0x0008	/* enable FLL mode (rw) */
#define STA_INS		0x0010	/* insert leap (rw) */
#define STA_DEL		0x0020	/* delete leap (rw) */
#define STA_UNSYNC	0x0040	/* clock unsynchronized (rw) */
#define STA_FREQHOLD	0x0080	/* hold frequency (rw) */
#define STA_PPSSIGNAL	0x0100	/* PPS signal present (ro) */
#define STA_PPSJITTER	0x0200	/* PPS signal jitter exceeded (ro) */
#define STA_PPSWANDER	0x0400	/* PPS signal wander exceeded (ro) */
#define STA_PPSERROR	0x0800	/* PPS signal calibration error (ro) */
#define STA_CLOCKERR	0x1000	/* clock hardware fault (ro) */
#define STA_NANO	0x2000	/* resolution (0 = us, 1 = ns) (ro) */
#define STA_MODE	0x4000	/* mode (0 = PLL, 1 = FLL) (ro) */
#define STA_CLK		0x8000	/* clock source (0 = A, 1 = B) (ro) */

#define STA_FMT	"\177\020\
b\0PLL\0\
b\1PPSFREQ\0\
b\2PPSTIME\0\
b\3FLL\0\
b\4INS\0\
b\5DEL\0\
b\6UNSYNC\0\
b\7FREQHOLD\0\
b\10PPSSIGNAL\0\
b\11PPSJITTER\0\
b\12PPSWANDER\0\
b\13PPSERROR\0\
b\14CLOCKERR\0\
b\15NANO\0\
f\16\1MODE\0=\0PLL\0=\1FLL\0\
f\17\1CLK\0=\0A\0=\1B\0"

#define STA_RONLY (STA_PPSSIGNAL | STA_PPSJITTER | STA_PPSWANDER | \
    STA_PPSERROR | STA_CLOCKERR | STA_NANO | STA_MODE | STA_CLK)

/*
 * Clock states (time_state)
 */
#define TIME_OK		0	/* no leap second warning */
#define TIME_INS	1	/* insert leap second warning */
#define TIME_DEL	2	/* delete leap second warning */
#define TIME_OOP	3	/* leap second in progress */
#define TIME_WAIT	4	/* leap second has occurred */
#define TIME_ERROR	5	/* error (see status word) */

/*
 * NTP user interface (ntp_gettime()) - used to read kernel clock values
 *
 * Note: The time member is in microseconds if STA_NANO is zero and
 * nanoseconds if not.
 */
struct ntptimeval {
	struct timespec time;	/* current time (ns) (ro) */
	long maxerror;		/* maximum error (us) (ro) */
	long esterror;		/* estimated error (us) (ro) */
	long tai;		/* TAI offset */
	int time_state;		/* time status */
};

/*
 * NTP daemon interface (ntp_adjtime()) - used to discipline CPU clock
 * oscillator and determine status.
 *
 * Note: The offset, precision and jitter members are in microseconds if
 * STA_NANO is zero and nanoseconds if not.
 */
struct timex {
	unsigned int modes;	/* clock mode bits (wo) */
	long	offset;		/* time offset (ns/us) (rw) */
	long	freq;		/* frequency offset (scaled PPM) (rw) */
	long	maxerror;	/* maximum error (us) (rw) */
	long	esterror;	/* estimated error (us) (rw) */
	int	status;		/* clock status bits (rw) */
	long	constant;	/* poll interval (log2 s) (rw) */
	long	precision;	/* clock precision (ns/us) (ro) */
	long	tolerance;	/* clock frequency tolerance (scaled
				 * PPM) (ro) */
	/*
	 * The following read-only structure members are implemented
	 * only if the PPS signal discipline is configured in the
	 * kernel. They are included in all configurations to insure
	 * portability.
	 */
	long	ppsfreq;	/* PPS frequency (scaled PPM) (ro) */
	long	jitter;		/* PPS jitter (ns/us) (ro) */
	int	shift;		/* interval duration (s) (shift) (ro) */
	long	stabil;		/* PPS stability (scaled PPM) (ro) */
	long	jitcnt;		/* jitter limit exceeded (ro) */
	long	calcnt;		/* calibration intervals (ro) */
	long	errcnt;		/* calibration errors (ro) */
	long	stbcnt;		/* stability limit exceeded (ro) */
};

#ifdef _KERNEL

#include <sys/mutex.h>

void	ntp_update_second(int64_t *adjustment, time_t *newsec);
void	ntp_adjtime1(struct timex *);
void	ntp_gettime(struct ntptimeval *);
int ntp_timestatus(void);

extern kmutex_t timecounter_lock;

extern int64_t time_adjtime;

#else /* !_KERNEL */

__BEGIN_DECLS
#ifndef __LIBC12_SOURCE__
int ntp_gettime(struct ntptimeval *) __RENAME(__ntp_gettime50);
#endif
int ntp_adjtime(struct timex *);
__END_DECLS

#endif /* _KERNEL */

#endif /* _SYS_TIMEX_H_ */