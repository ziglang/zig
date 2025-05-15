/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2022 Marshall Kirk McKusick <mckusick@mckusick.com>
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef	_G_UNION_H_
#define	_G_UNION_H_

#define	G_UNION_CLASS_NAME	"UNION"
#define	G_UNION_VERSION		1
#define	G_UNION_SUFFIX		".union"
/*
 * Special flag to instruct gunion to passthrough the underlying provider's
 * physical path
 */
#define G_UNION_PHYSPATH_PASSTHROUGH "\255"

#ifdef _KERNEL
#define	G_UNION_DEBUG(lvl, ...) \
    _GEOM_DEBUG("GEOM_UNION", g_union_debug, (lvl), NULL, __VA_ARGS__)
#define G_UNION_LOGREQLVL(lvl, bp, ...) \
    _GEOM_DEBUG("GEOM_UNION", g_union_debug, (lvl), (bp), __VA_ARGS__)
#define	G_UNION_LOGREQ(bp, ...)	G_UNION_LOGREQLVL(3, (bp), __VA_ARGS__)

TAILQ_HEAD(wiplist, g_union_wip);

/*
 * State maintained by each instance of a UNION GEOM.
 */
struct g_union_softc {
	struct rwlock	   sc_rwlock;		/* writemap lock */
	uint64_t	 **sc_writemap_root;	/* root of write map */
	uint64_t	  *sc_leafused;		/* 1 => leaf has allocation */
	uint64_t	   sc_map_size;		/* size of write map */
	long		   sc_root_size;	/* entries in root node */
	long		   sc_leaf_size;	/* entries in leaf node */
	long		   sc_bits_per_leaf;	/* bits per leaf node entry */
	long		   sc_writemap_memory;	/* memory used by writemap */
	off_t		   sc_offset;		/* starting offset in lower */
	off_t		   sc_size;		/* size of union geom */
	off_t		   sc_sectorsize;	/* sector size of geom */
	struct g_consumer *sc_uppercp;		/* upper-level provider */
	struct g_consumer *sc_lowercp;		/* lower-level provider */
	struct wiplist	   sc_wiplist;		/* I/O work-in-progress list */
	long		   sc_flags;		/* see flags below */
	long		   sc_reads;		/* number of reads done */
	long		   sc_wrotebytes;	/* number of bytes written */
	long		   sc_writes;		/* number of writes done */
	long		   sc_readbytes;	/* number of bytes read */
	long		   sc_deletes;		/* number of deletes done */
	long		   sc_getattrs;		/* number of getattrs done */
	long		   sc_flushes;		/* number of flushes done */
	long		   sc_cmd0s;		/* number of cmd0's done */
	long		   sc_cmd1s;		/* number of cmd1's done */
	long		   sc_cmd2s;		/* number of cmd2's done */
	long		   sc_speedups;		/* number of speedups done */
	long		   sc_readcurrentread;	/* reads current with read */
	long		   sc_readblockwrite;	/* writes blocked by read */
	long		   sc_writeblockread;	/* reads blocked by write */
	long		   sc_writeblockwrite;	/* writes blocked by write */
};

/*
 * Structure to track work-in-progress I/O operations.
 *
 * Used to prevent overlapping I/O operations from running concurrently.
 * Created for each I/O operation.
 *
 * In usual case of no overlap it is linked to sc_wiplist and started.
 * If found to overlap an I/O on sc_wiplist, it is not started and is
 * linked to wip_waiting list of the I/O that it overlaps. When an I/O
 * completes, it restarts all the I/O operations on its wip_waiting list.
 */
struct g_union_wip {
	struct wiplist		 wip_waiting;	/* list of I/Os waiting on me */
	TAILQ_ENTRY(g_union_wip) wip_next;	/* pending or active I/O list */
	struct bio		*wip_bp;	/* bio for this I/O */
	struct g_union_softc	*wip_sc;	/* g_union's softc */
	off_t			 wip_start;	/* starting offset of I/O */
	off_t			 wip_end;	/* ending offset of I/O */
	long			 wip_numios;	/* BIO_READs in progress */
	long			 wip_error;	/* merged I/O errors */
};

/*
 * UNION flags
 */
#define DOING_COMMIT	0x00000001	/* a commit command is in progress */

#define DOING_COMMIT_BITNUM	 0	/* a commit command is in progress */

#define BITS_PER_ENTRY	(sizeof(uint64_t) * NBBY)
#define G_RLOCK(sc)	rw_rlock(&(sc)->sc_rwlock)
#define G_RUNLOCK(sc)	rw_runlock(&(sc)->sc_rwlock)
#define G_WLOCK(sc)	rw_wlock(&(sc)->sc_rwlock)
#define G_WUNLOCK(sc)	rw_wunlock(&(sc)->sc_rwlock)
#define G_WLOCKOWNED(sc) rw_assert(&(sc)->sc_rwlock, RA_WLOCKED)

/*
 * The writelock is held while a commit operation is in progress.
 * While held union device may not be used or in use.
 * Returns == 0 if lock was successfully obtained.
 */
static inline int
g_union_get_writelock(struct g_union_softc *sc)
{

	return (atomic_testandset_long(&sc->sc_flags, DOING_COMMIT_BITNUM));
}

static inline void
g_union_rel_writelock(struct g_union_softc *sc)
{
	long ret __diagused;

	ret = atomic_testandclear_long(&sc->sc_flags, DOING_COMMIT_BITNUM);
	KASSERT(ret != 0, ("UNION GEOM releasing unheld lock"));
}

#endif	/* _KERNEL */

#endif	/* _G_UNION_H_ */