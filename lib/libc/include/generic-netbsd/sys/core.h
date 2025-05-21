/*	$NetBSD: core.h,v 1.12 2009/08/20 22:07:49 he Exp $	*/

/*-
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Paul Kranenburg.
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

#ifndef _SYS_CORE_H_
#define _SYS_CORE_H_

#define COREMAGIC	0507
#define CORESEGMAGIC	0510

/*
 * The core structure's c_midmag field (like exec's a_midmag) is a
 * network-byteorder encoding of this int
 *	FFFFFFmmmmmmmmmmMMMMMMMMMMMMMMMM
 * Where `F' is 6 bits of flag (currently unused),
 *       `m' is 10 bits of machine-id, and
 *       `M' is 16 bits worth of magic number, ie. COREMAGIC.
 * The macros below will set/get the needed fields.
 */
#define	CORE_GETMAGIC(c)  (  ntohl(((c).c_midmag))        & 0xffff )
#define	CORE_GETMID(c)    ( (ntohl(((c).c_midmag)) >> 16) & 0x03ff )
#define	CORE_GETFLAG(c)   ( (ntohl(((c).c_midmag)) >> 26) & 0x03f  )
#define	CORE_SETMAGIC(c,mag,mid,flag) ( (c).c_midmag = htonl ( \
			( ((flag) & 0x3f)   << 26) | \
			( ((mid)  & 0x03ff) << 16) | \
			( ((mag)  & 0xffff)      ) ) )

/* Flag definitions */
#define CORE_CPU	1
#define CORE_DATA	2
#define CORE_STACK	4

#include <sys/aout_mids.h>

/*
 * A core file consists of a header followed by a number of segments.
 * Each segment is preceded by a `coreseg' structure giving the
 * segment's type, the virtual address where the bits resided in
 * process address space and the size of the segment.
 *
 * The core header specifies the lengths of the core header itself and
 * each of the following core segment headers to allow for any machine
 * dependent alignment requirements.
 */

struct core {
	uint32_t c_midmag;		/* magic, id, flags */
	uint16_t c_hdrsize;		/* Size of this header (machdep algn) */
	uint16_t c_seghdrsize;		/* Size of a segment header */
	uint32_t c_nseg;		/* # of core segments */
	char	c_name[MAXCOMLEN+1];	/* Copy of p->p_comm */
	uint32_t c_signo;		/* Killing signal */
	u_long	c_ucode;		/* Hmm ? */
	u_long	c_cpusize;		/* Size of machine dependent segment */
	u_long	c_tsize;		/* Size of traditional text segment */
	u_long	c_dsize;		/* Size of traditional data segment */
	u_long	c_ssize;		/* Size of traditional stack segment */
};

struct coreseg {
	uint32_t c_midmag;		/* magic, id, flags */
	u_long	c_addr;			/* Virtual address of segment */
	u_long	c_size;			/* Size of this segment */
};

/*
 * 32-bit versions of the above.
 */
struct core32 {
	uint32_t c_midmag;		/* magic, id, flags */
	uint16_t c_hdrsize;		/* Size of this header (machdep algn) */
	uint16_t c_seghdrsize;		/* Size of a segment header */
	uint32_t c_nseg;		/* # of core segments */
	char	c_name[MAXCOMLEN+1];	/* Copy of p->p_comm */
	uint32_t c_signo;		/* Killing signal */
	u_int	c_ucode;		/* Hmm ? */
	u_int	c_cpusize;		/* Size of machine dependent segment */
	u_int	c_tsize;		/* Size of traditional text segment */
	u_int	c_dsize;		/* Size of traditional data segment */
	u_int	c_ssize;		/* Size of traditional stack segment */
};

struct coreseg32 {
	uint32_t c_midmag;		/* magic, id, flags */
	u_int	c_addr;			/* Virtual address of segment */
	u_int	c_size;			/* Size of this segment */
};

#endif /* !_SYS_CORE_H_ */