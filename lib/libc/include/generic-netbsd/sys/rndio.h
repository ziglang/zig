/*	$NetBSD: rndio.h,v 1.2.50.1 2023/08/11 14:35:25 martin Exp $	*/

/*-
 * Copyright (c) 1997 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Michael Graff <explorer@flame.org>.  This code uses ideas and
 * algorithms from the Linux driver written by Ted Ts'o.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_SYS_RNDIO_H
#define	_SYS_RNDIO_H

#include <sys/types.h>
#include <sys/sha1.h>
#include <sys/ioccom.h>

/*
 * Exposed "size" of entropy pool, for convenience in load/save
 * from userspace.  Do not assume this is the same as the actual in-kernel
 * pool size!
 */
#define RND_SAVEWORDS	128
typedef struct {
	uint32_t entropy;
	uint8_t data[RND_SAVEWORDS * sizeof(uint32_t)];
	uint8_t digest[SHA1_DIGEST_LENGTH];
} rndsave_t;

/* Statistics exposed by RNDGETPOOLSTAT */
typedef struct {
	uint32_t	poolsize;
	uint32_t 	threshold;
	uint32_t	maxentropy;

	uint32_t	added;
	uint32_t	curentropy;
	uint32_t	removed;
	uint32_t	discarded;
	uint32_t	generated;
} rndpoolstat_t;

/* Sanitized random source view for userspace */
typedef struct {
	char		name[16];	/* device name */
	uint32_t	total;		/* entropy from this source */
	uint32_t	type;		/* type */
	uint32_t	flags;		/* flags */
} rndsource_t;

typedef struct {
	rndsource_t	rt;
	uint32_t	dt_samples;	/* time-delta samples input */
	uint32_t	dt_total;	/* time-delta entropy estimate */
	uint32_t	dv_samples;	/* value-delta samples input */
	uint32_t	dv_total;	/* value-delta entropy estimate */
} rndsource_est_t;

/*
 * Flags to control the source.  Low byte is type, upper bits are flags.
 */
#define RND_FLAG_NO_ESTIMATE	0x00000100
#define RND_FLAG_NO_COLLECT	0x00000200
#define RND_FLAG_FAST		0x00000400	/* process samples in bulk */
#define RND_FLAG_HASCB		0x00000800	/* has get callback */
#define RND_FLAG_COLLECT_TIME	0x00001000	/* use timestamp as input */
#define RND_FLAG_COLLECT_VALUE	0x00002000	/* use value as input */
#define RND_FLAG_ESTIMATE_TIME	0x00004000	/* estimate entropy on time */
#define RND_FLAG_ESTIMATE_VALUE	0x00008000	/* estimate entropy on value */
#define	RND_FLAG_HASENABLE	0x00010000	/* has enable/disable fns */
#define RND_FLAG_DEFAULT	(RND_FLAG_COLLECT_VALUE|RND_FLAG_COLLECT_TIME|\
				 RND_FLAG_ESTIMATE_TIME)

#define	RND_TYPE_UNKNOWN	0	/* unknown source */
#define	RND_TYPE_DISK		1	/* source is physical disk */
#define	RND_TYPE_NET		2	/* source is a network device */
#define	RND_TYPE_TAPE		3	/* source is a tape drive */
#define	RND_TYPE_TTY		4	/* source is a tty device */
#define	RND_TYPE_RNG		5	/* source is a hardware RNG */
#define RND_TYPE_SKEW		6	/* source is skew between clocks */
#define RND_TYPE_ENV		7	/* source is temp or fan sensor */
#define RND_TYPE_VM		8	/* source is VM system events */
#define RND_TYPE_POWER		9	/* source is power events */
#define	RND_TYPE_MAX		9	/* last type id used */

#define	RND_MAXSTATCOUNT	10	/* 10 sources at once max */

/*
 * return "count" random entries, starting at "start"
 */
typedef struct {
	uint32_t	start;
	uint32_t	count;
	rndsource_t	source[RND_MAXSTATCOUNT];
} rndstat_t;

/*
 * return "count" random entries with estimates, starting at "start"
 */
typedef struct {
	uint32_t	start;
	uint32_t	count;
	rndsource_est_t	source[RND_MAXSTATCOUNT];
} rndstat_est_t;

/*
 * return information on a specific source by name
 */
typedef struct {
	char		name[16];
	rndsource_t	source;
} rndstat_name_t;

typedef struct {
	char		name[16];
	rndsource_est_t	source;
} rndstat_est_name_t;


/*
 * set/clear device flags.  If type is set to 0xff, the name is used
 * instead.  Otherwise, the flags set/cleared apply to all devices of
 * the specified type, and the name is ignored.
 */
typedef struct {
	char		name[16];	/* the name we are adjusting */
	uint32_t	type;		/* the type of device we want */
	uint32_t	flags;		/* flags to set or clear */
	uint32_t	mask;		/* mask for the flags we are setting */
} rndctl_t;

/*
 * Add entropy to the pool.  len is the data length, in bytes.
 * entropy is the number of bits of estimated entropy in the data.
 */
typedef struct {
	uint32_t	len;
	uint32_t	entropy;
	u_char		data[RND_SAVEWORDS * sizeof(uint32_t)];
} rnddata_t;

#define	RNDGETENTCNT	_IOR('R',  101, uint32_t) /* get entropy count */
#define	RNDGETSRCNUM	_IOWR('R', 102, rndstat_t) /* get rnd source info */
#define	RNDGETSRCNAME	_IOWR('R', 103, rndstat_name_t) /* get src by name */
#define	RNDCTL		_IOW('R',  104, rndctl_t)  /* set/clear source flags */
#define	RNDADDDATA	_IOW('R',  105, rnddata_t) /* add data to the pool */
#define	RNDGETPOOLSTAT	_IOR('R',  106, rndpoolstat_t) /* get statistics */
#define	RNDGETESTNUM	_IOWR('R', 107, rndstat_est_t) /* get srcest */
#define	RNDGETESTNAME	_IOWR('R', 108, rndstat_est_name_t) /* " by name */

#endif	/* _SYS_RNDIO_H */