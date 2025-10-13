/*	$NetBSD: devmap.h,v 1.1 2002/02/10 01:57:13 thorpej Exp $	*/

/*
 * Copyright 1997
 * Digital Equipment Corporation. All rights reserved.
 *
 * This software is furnished under license and may be used and
 * copied only in accordance with the following terms and conditions.
 * Subject to these conditions, you may download, copy, install,
 * use, modify and distribute this software in source and/or binary
 * form. No title or ownership is transferred hereby.
 *
 * 1) Any source code used, modified or distributed must reproduce
 *    and retain this copyright notice and list of conditions as
 *    they appear in the source file.
 *
 * 2) No right is granted to use any trade name, trademark, or logo of
 *    Digital Equipment Corporation. Neither the "Digital Equipment
 *    Corporation" name nor any trademark or logo of Digital Equipment
 *    Corporation may be used to endorse or promote products derived
 *    from this software without the prior written permission of
 *    Digital Equipment Corporation.
 *
 * 3) This software is provided "AS-IS" and any express or implied
 *    warranties, including but not limited to, any implied warranties
 *    of merchantability, fitness for a particular purpose, or
 *    non-infringement are disclaimed. In no event shall DIGITAL be
 *    liable for any damages whatsoever, and in particular, DIGITAL
 *    shall not be liable for special, indirect, consequential, or
 *    incidental damages or damages for lost profits, loss of
 *    revenue or loss of use, whether such damages arise in contract,
 *    negligence, tort, under statute, in equity, at law or otherwise,
 *    even if advised of the possibility of such damage.
 */

/*
** devmap.h -- device memory mapping definitions
**
**  <-----------------map size------------------------->
**  <--internal offset--><--internal size-->
**  |--------------------|------------------|----------|
**  v                    v                  v          v
**  page               device            device      page
**  start              memory            memory       end
** (map offset)        start             end
*/

#ifndef _DEVMAP_H_
#define _DEVMAP_H_

#include <sys/types.h>

#define MAP_INFO_UNKNOWN -1
#define MAP_IOCTL 0
#define MAP_MMAP  1
#define MAP_I386_IOMAP 3

struct map_info {
    int method;      /* Mapping method - eg. IOCTL, MMAP, or I386_IOMAP */
    u_long size;     /* size of region, in bus-space units */
    union {
	long maxmapinfo[64/sizeof(long)];
	struct {
	    int placeholder;       /* nothing needed */
	} map_info_ioctl;          /* used for ioctl method */
	struct {
	    off_t map_offset;      /* offset to be given to mmap, page aligned */
	    size_t map_size;       /* size to be given to mmap, page aligned */ 
	    off_t internal_offset; /* internal offset in mapped rgn to data */
	    size_t internal_size;  /* actual size of accessible region */
	} map_info_mmap;           /* used for mmap'd methods */
	struct {
	    u_long start_port;
	} map_info_i386_iomap;
    } u;
};

#endif /* _DEVMAP_H_ */