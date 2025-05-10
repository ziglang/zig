/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2012 EMC Corp.
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
 */

#ifndef _SYS_MEMDESC_H_
#define	_SYS_MEMDESC_H_

struct bio;
struct bus_dma_segment;
struct uio;
struct mbuf;
struct vm_page;
union ccb;

/*
 * struct memdesc encapsulates various memory descriptors and provides
 * abstract access to them.
 */
struct memdesc {
	union {
		void			*md_vaddr;
		vm_paddr_t		md_paddr;
		struct bus_dma_segment	*md_list;
		struct uio		*md_uio;
		struct mbuf		*md_mbuf;
		struct vm_page 		**md_ma;
	} u;
	union {				/* type specific data. */
		size_t		md_len;	/* VADDR, PADDR, VMPAGES */
		int		md_nseg; /* VLIST, PLIST */
	};
	union {
		uint32_t	md_offset; /* VMPAGES */
	};
	uint32_t	md_type;	/* Type of memory. */
};

#define	MEMDESC_VADDR	1	/* Contiguous virtual address. */
#define	MEMDESC_PADDR	2	/* Contiguous physical address. */
#define	MEMDESC_VLIST	3	/* scatter/gather list of kva addresses. */
#define	MEMDESC_PLIST	4	/* scatter/gather list of physical addresses. */
#define	MEMDESC_UIO	6	/* Pointer to a uio (any io). */
#define	MEMDESC_MBUF	7	/* Pointer to a mbuf (network io). */
#define	MEMDESC_VMPAGES	8	/* Pointer to array of VM pages. */

static inline struct memdesc
memdesc_vaddr(void *vaddr, size_t len)
{
	struct memdesc mem;

	mem.u.md_vaddr = vaddr;
	mem.md_len = len;
	mem.md_type = MEMDESC_VADDR;

	return (mem);
}

static inline struct memdesc
memdesc_paddr(vm_paddr_t paddr, size_t len)
{
	struct memdesc mem;

	mem.u.md_paddr = paddr;
	mem.md_len = len;
	mem.md_type = MEMDESC_PADDR;

	return (mem);
}

static inline struct memdesc
memdesc_vlist(struct bus_dma_segment *vlist, int sglist_cnt)
{
	struct memdesc mem;

	mem.u.md_list = vlist;
	mem.md_nseg = sglist_cnt;
	mem.md_type = MEMDESC_VLIST;

	return (mem);
}

static inline struct memdesc
memdesc_plist(struct bus_dma_segment *plist, int sglist_cnt)
{
	struct memdesc mem;

	mem.u.md_list = plist;
	mem.md_nseg = sglist_cnt;
	mem.md_type = MEMDESC_PLIST;

	return (mem);
}

static inline struct memdesc
memdesc_uio(struct uio *uio)
{
	struct memdesc mem;

	mem.u.md_uio = uio;
	mem.md_type = MEMDESC_UIO;

	return (mem);
}

static inline struct memdesc
memdesc_mbuf(struct mbuf *mbuf)
{
	struct memdesc mem;

	mem.u.md_mbuf = mbuf;
	mem.md_type = MEMDESC_MBUF;

	return (mem);
}

static inline struct memdesc
memdesc_vmpages(struct vm_page **ma, size_t len, u_int ma_offset)
{
	struct memdesc mem;

	mem.u.md_ma = ma;
	mem.md_len = len;
	mem.md_type = MEMDESC_VMPAGES;
	mem.md_offset = ma_offset;

	return (mem);
}

struct memdesc	memdesc_bio(struct bio *bio);
struct memdesc	memdesc_ccb(union ccb *ccb);

/*
 * Similar to m_copyback/data, *_copyback copy data from the 'src'
 * buffer into the memory descriptor's data buffer while *_copydata
 * copy data from the memory descriptor's data buffer into the the
 * 'dst' buffer.
 */
void	memdesc_copyback(struct memdesc *mem, int off, int size,
    const void *src);
void	memdesc_copydata(struct memdesc *mem, int off, int size, void *dst);

#endif /* _SYS_MEMDESC_H_ */