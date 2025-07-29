/*	$NetBSD: agpio.h,v 1.13 2021/12/19 01:51:17 riastradh Exp $	*/

/*-
 * Copyright (c) 2000 Doug Rabson
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
 *	$FreeBSD: src/sys/sys/agpio.h,v 1.1 2000/06/09 16:04:30 dfr Exp $
 */

#ifndef _SYS_AGPIO_H_
#define _SYS_AGPIO_H_

#include <sys/types.h>
#include <sys/ioccom.h>

/*
 * The AGP gatt uses 4k pages irrespective of the host page size.
 */
#define AGP_PAGE_SIZE		4096
#define AGP_PAGE_SHIFT		12

/*
 * Macros to manipulate AGP mode words.
 */
#define AGP_MODE_GET_RQ(x)		__SHIFTOUT((x), AGP_MODE_RQ)
#define AGP_MODE_GET_ARQSZ(x)		__SHIFTOUT((x), AGP_MODE_ARQSZ)
#define AGP_MODE_GET_CAL(x)		__SHIFTOUT((x), AGP_MODE_CAL)
#define AGP_MODE_GET_SBA(x)		__SHIFTOUT((x), AGP_MODE_SBA)
#define AGP_MODE_GET_AGP(x)		__SHIFTOUT((x), AGP_MODE_AGP)
#define AGP_MODE_GET_4G(x)		__SHIFTOUT((x), AGP_MODE_4G)
#define AGP_MODE_GET_FW(x)		__SHIFTOUT((x), AGP_MODE_FW)
#define AGP_MODE_GET_MODE_3(x)		__SHIFTOUT((x), AGP_MODE_MODE_3)
#define AGP_MODE_GET_RATE(x)		__SHIFTOUT((x), AGP_MODE_RATE)
#define AGP_MODE_SET_RQ(x, v)		(((x) & ~AGP_MODE_RQ)		\
					 | __SHIFTIN((v), AGP_MODE_RQ))
#define AGP_MODE_SET_ARQSZ(x, v)	(((x) & ~AGP_MODE_ARQSZ)	\
					 | __SHIFTIN((v), AGP_MODE_ARQSZ))
#define AGP_MODE_SET_CAL(x, v)		(((x) & ~AGP_MODE_CAL)		\
					 | __SHIFTIN((v), ~AGP_MODE_CAL))
#define AGP_MODE_SET_SBA(x, v)		(((x) & ~AGP_MODE_SBA)		\
					 | __SHIFTIN((v), AGP_MODE_SBA))
#define AGP_MODE_SET_AGP(x, v)		(((x) & ~AGP_MODE_AGP)		\
					 | __SHIFTIN((v), AGP_MODE_AGP))
#define AGP_MODE_SET_4G(x, v)		(((x) & ~AGP_MODE_4G)		\
					 | __SHIFTIN((v), AGP_MODE_4G))
#define AGP_MODE_SET_FW(x, v)		(((x) & ~AGP_MODE_FW)		\
					 | __SHIFTIN((v), AGP_MODE_FW))
#define AGP_MODE_SET_MODE_3(x, v)	(((x) & ~AGP_MODE_MODE_3)	\
					 | __SHIFTIN((v), AGP_MODE_MODE_3))
#define AGP_MODE_SET_RATE(x, v)		(((x) & ~AGP_MODE_RATE)		\
					 | __SHIFTIN((v), AGP_MODE_RATE))

/* compat */
#define AGP_MODE_RATE_1x		AGP_MODE_V2_RATE_1x
#define AGP_MODE_RATE_2x		AGP_MODE_V2_RATE_2x
#define AGP_MODE_RATE_4x		AGP_MODE_V2_RATE_4x

#define AGPIOC_BASE       'A'
#define AGPIOC_INFO       _IOR (AGPIOC_BASE, 0, agp_info)
#define AGPIOC_ACQUIRE    _IO  (AGPIOC_BASE, 1)
#define AGPIOC_RELEASE    _IO  (AGPIOC_BASE, 2)
#define AGPIOC_SETUP      _IOW (AGPIOC_BASE, 3, agp_setup)
#if 0
#define AGPIOC_RESERVE    _IOW (AGPIOC_BASE, 4, agp_region)
#define AGPIOC_PROTECT    _IOW (AGPIOC_BASE, 5, agp_region)
#endif
#define AGPIOC_ALLOCATE   _IOWR(AGPIOC_BASE, 6, agp_allocate)
#define AGPIOC_DEALLOCATE _IOW (AGPIOC_BASE, 7, int)
#define AGPIOC_BIND       _IOW (AGPIOC_BASE, 8, agp_bind)
#define AGPIOC_UNBIND     _IOW (AGPIOC_BASE, 9, agp_unbind)

typedef struct _agp_version {
	uint16_t major;
	uint16_t minor;
} agp_version;

typedef struct _agp_info {
	agp_version version;	/* version of the driver        */
	uint32_t bridge_id;	/* bridge vendor/device         */
	uint32_t agp_mode;	/* mode info of bridge          */
	off_t aper_base;	/* base of aperture             */
	size_t aper_size;	/* size of aperture             */
	size_t pg_total;	/* max pages (swap + system)    */
	size_t pg_system;	/* max pages (system)           */
	size_t pg_used;		/* current pages used           */
} agp_info;

typedef struct _agp_setup {
	uint32_t agp_mode;		/* mode info of bridge          */
} agp_setup;

#if 0
/*
 * The "prot" down below needs still a "sleep" flag somehow ...
 */
typedef struct _agp_segment {
	off_t pg_start;		/* starting page to populate    */
	size_t pg_count;	/* number of pages              */
	int prot;		/* prot flags for mmap          */
} agp_segment;

typedef struct _agp_region {
	pid_t pid;		/* pid of process               */
	size_t seg_count;	/* number of segments           */
	struct _agp_segment *seg_list;
} agp_region;
#endif

typedef struct _agp_allocate {
	int key;		/* tag of allocation            */
	size_t pg_count;	/* number of pages              */
	uint32_t type;		/* 0 == normal, other devspec   */
	uint32_t physical;	/* device specific (some devices
				 * need a phys address of the
				 * actual page behind the gatt
				 * table)                        */
} agp_allocate;

typedef struct _agp_bind {
	int key;		/* tag of allocation            */
	off_t pg_start;		/* starting page to populate    */
} agp_bind;

typedef struct _agp_unbind {
	int key;		/* tag of allocation            */
	uint32_t priority;	/* priority for paging out      */
} agp_unbind;

#endif /* !_SYS_AGPIO_H_ */