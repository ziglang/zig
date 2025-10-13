/*	$NetBSD: iostat.h,v 1.12 2019/05/22 08:47:02 hannken Exp $	*/

/*-
 * Copyright (c) 1996, 1997, 2004, 2009 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center.
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

#ifndef _SYS_IOSTAT_H_
#define _SYS_IOSTAT_H_

/*
 * Disk device structures.
 */

#include <sys/time.h>
#include <sys/queue.h>

#define	IOSTATNAMELEN	16

/* types of drives we can have */
#define IOSTAT_DISK	0
#define IOSTAT_TAPE	1
#define IOSTAT_NFS	2

/* The following structure is 64-bit alignment safe */
struct io_sysctl {
	char		name[IOSTATNAMELEN];
	int32_t		busy;
	int32_t		type;
	u_int64_t	xfer;
	u_int64_t	seek;
	u_int64_t	bytes;
	u_int32_t	attachtime_sec;
	u_int32_t	attachtime_usec;
	u_int32_t	timestamp_sec;
	u_int32_t	timestamp_usec;
	u_int32_t	time_sec;
	u_int32_t	time_usec;
	/* New separate read/write stats */
	u_int64_t	rxfer;
	u_int64_t	rbytes;
	u_int64_t	wxfer;
	u_int64_t	wbytes;
	/*
	 * New queue stats
	 * accumulated wait time (iostat_wait .. iostat_busy)
	 * accumulated wait sum (wait time * count)
	 * accumulated busy sum (busy time * count)
	 */
	u_int32_t	wait_sec;
	u_int32_t	wait_usec;
	u_int32_t	waitsum_sec;
	u_int32_t	waitsum_usec;
	u_int32_t	busysum_sec;
	u_int32_t	busysum_usec;
};

/*
 * Structure for keeping the in-kernel drive stats - these are linked
 * together in drivelist.
 */

struct io_stats {
	char		io_name[IOSTATNAMELEN];  /* device name */
	void		*io_parent; /* pointer to what we are attached to */
	int		io_type;   /* type of device the state belong to */
	int		io_busy;	/* busy counter */
	int		io_wait;	/* wait counter */
	u_int64_t	io_rxfer;	/* total number of read transfers */
	u_int64_t	io_wxfer;	/* total number of write transfers */
	u_int64_t	io_seek;	/* total independent seek operations */
	u_int64_t	io_rbytes;	/* total bytes read */
	u_int64_t	io_wbytes;	/* total bytes written */
	struct timeval	io_attachtime;	/* time disk was attached */
	struct timeval	io_timestamp;	/* timestamp of last unbusy */
	struct timeval	io_busystamp;	/* timestamp of last busy */
	struct timeval	io_waitstamp;	/* timestamp of last wait */
	struct timeval	io_busysum;	/* accumulated wait * time */
	struct timeval	io_waitsum;	/* accumulated busy * time */
	struct timeval	io_busytime;	/* accumlated time busy */
	struct timeval	io_waittime;	/* accumlated time waiting */
	TAILQ_ENTRY(io_stats) io_link;
};

/*
 * drivelist_head is defined here so that user-land has access to it.
 */
TAILQ_HEAD(iostatlist_head, io_stats);	/* the iostatlist is a TAILQ */

#ifdef _KERNEL
void	iostat_init(void);
void	iostat_wait(struct io_stats *);
void	iostat_busy(struct io_stats *);
void	iostat_unbusy(struct io_stats *, long, int);
bool	iostat_isbusy(struct io_stats *);
struct io_stats *iostat_find(const char *);
struct io_stats *iostat_alloc(int32_t, void *, const char *);
void	iostat_free(struct io_stats *);
void	iostat_rename(struct io_stats *, const char *);
void	iostat_seek(struct io_stats *);
#endif

#endif /* _SYS_IOSTAT_H_ */