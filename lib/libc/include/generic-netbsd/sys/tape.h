/*	$NetBSD: tape.h,v 1.4 2016/01/22 23:44:33 dholland Exp $	*/

/*-
 * Copyright (c) 2005 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Brett Lymn
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Neither the name of The NetBSD Foundation nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

#ifndef _SYS_TAPE_H_
#define _SYS_TAPE_H_

#include <sys/queue.h>
#include <sys/time.h>

#define	TAPENAMELEN	16

/* The following structure is 64-bit alignment safe */
struct tape_sysctl {
	char		name[TAPENAMELEN];
	int32_t		busy;
	int32_t		pad;
	uint64_t	xfer;
	uint64_t	bytes;
	uint32_t	attachtime_sec;
	uint32_t	attachtime_usec;
	uint32_t	timestamp_sec;
	uint32_t	timestamp_usec;
	uint32_t	time_sec;
	uint32_t	time_usec;
	uint64_t	rxfer;
	uint64_t	rbytes;
	uint64_t	wxfer;
	uint64_t	wbytes;
};

/*
 * Statistics for the tape device - in a separate structure so userland can
 * see them.
 */

struct tape {
	char		*name; 		/* name of drive */
	int		busy;		/* drive is busy */
	uint64_t       rxfer;		/* total number of read transfers */
	uint64_t       wxfer;		/* total number of write transfers */
	uint64_t       rbytes;		/* total bytes read */
	uint64_t       wbytes;		/* total bytes written */
	struct timeval  attachtime;	/* time tape was attached */
	struct timeval  timestamp;	/* timestamp of last unbusy */
	struct timeval  time;		/* total time spent busy */

	TAILQ_ENTRY(tape) link;
};

/* Head of the tape stats list, define here so userland can get at it */
TAILQ_HEAD(tapelist_head, tape);	/* the tapelist is a TAILQ */

#endif