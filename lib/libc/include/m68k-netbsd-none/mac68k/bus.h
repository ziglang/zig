/*	$NetBSD: bus.h,v 1.30 2021/01/23 19:38:08 christos Exp $	*/

/*-
 * Copyright (c) 1996, 1997, 1998 The NetBSD Foundation, Inc.
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

/*
 * Copyright (C) 1997 Scott Reynolds.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
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

#ifndef _MAC68K_BUS_H_
#define _MAC68K_BUS_H_

/*
 * Value for the mac68k bus space tag, not to be used directly by MI code.
 */
#define MAC68K_BUS_SPACE_MEM	0	/* space is mem space */

#define __BUS_SPACE_HAS_STREAM_METHODS 1

/*
 * Bus address and size types
 */
typedef u_long bus_addr_t;
typedef u_long bus_size_t;

#define PRIxBUSADDR	"lx"
#define PRIxBUSSIZE	"lx"
#define PRIuBUSSIZE	"lu"
/*
 * Access methods for bus resources and address space.
 */
#define BSH_T	struct bus_space_handle_s
typedef int	bus_space_tag_t;
typedef struct bus_space_handle_s {
	u_long	base;
	int	swapped;
	int	stride;

	u_int8_t	(*bsr1)(bus_space_tag_t, BSH_T *, bus_size_t);
	u_int16_t	(*bsr2)(bus_space_tag_t, BSH_T *, bus_size_t);
	u_int32_t	(*bsr4)(bus_space_tag_t, BSH_T *, bus_size_t);
	u_int8_t	(*bsrs1)(bus_space_tag_t, BSH_T *, bus_size_t);
	u_int16_t	(*bsrs2)(bus_space_tag_t, BSH_T *, bus_size_t);
	u_int32_t	(*bsrs4)(bus_space_tag_t, BSH_T *, bus_size_t);
	void		(*bsrm1)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int8_t *, size_t);
	void		(*bsrm2)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int16_t *, size_t);
	void		(*bsrm4)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int32_t *, size_t);
	void		(*bsrms1)(bus_space_tag_t, BSH_T *, bus_size_t,
				  u_int8_t *, size_t);
	void		(*bsrms2)(bus_space_tag_t, BSH_T *, bus_size_t,
				  u_int16_t *, size_t);
	void		(*bsrms4)(bus_space_tag_t, BSH_T *, bus_size_t,
				  u_int32_t *, size_t);
	void		(*bsrr1)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int8_t *, size_t);
	void		(*bsrr2)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int16_t *, size_t);
	void		(*bsrr4)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int32_t *, size_t);
	void		(*bsrrs1)(bus_space_tag_t, BSH_T *, bus_size_t,
				  u_int8_t *, size_t);
	void		(*bsrrs2)(bus_space_tag_t, BSH_T *, bus_size_t,
				  u_int16_t *, size_t);
	void		(*bsrrs4)(bus_space_tag_t, BSH_T *, bus_size_t,
				  u_int32_t *, size_t);
	void		(*bsw1)(bus_space_tag_t, BSH_T *, bus_size_t, u_int8_t);
	void		(*bsw2)(bus_space_tag_t, BSH_T *, bus_size_t,
				u_int16_t);
	void		(*bsw4)(bus_space_tag_t, BSH_T *, bus_size_t,
				u_int32_t);
	void		(*bsws1)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int8_t);
	void		(*bsws2)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int16_t);
	void		(*bsws4)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int32_t);
	void		(*bswm1)(bus_space_tag_t, BSH_T *, bus_size_t,
				 const u_int8_t *, size_t);
	void		(*bswm2)(bus_space_tag_t, BSH_T *, bus_size_t,
				 const u_int16_t *, size_t);
	void		(*bswm4)(bus_space_tag_t, BSH_T *, bus_size_t,
				 const u_int32_t *, size_t);
	void		(*bswms1)(bus_space_tag_t, BSH_T *, bus_size_t,
				  const u_int8_t *, size_t);
	void		(*bswms2)(bus_space_tag_t, BSH_T *, bus_size_t,
				  const u_int16_t *, size_t);
	void		(*bswms4)(bus_space_tag_t, BSH_T *, bus_size_t,
				  const u_int32_t *, size_t);
	void		(*bswr1)(bus_space_tag_t, BSH_T *, bus_size_t,
				 const u_int8_t *, size_t);
	void		(*bswr2)(bus_space_tag_t, BSH_T *, bus_size_t,
				 const u_int16_t *, size_t);
	void		(*bswr4)(bus_space_tag_t, BSH_T *, bus_size_t,
				 const u_int32_t *, size_t);
	void		(*bswrs1)(bus_space_tag_t, BSH_T *, bus_size_t,
				  const u_int8_t *, size_t);
	void		(*bswrs2)(bus_space_tag_t, BSH_T *, bus_size_t,
				  const u_int16_t *, size_t);
	void		(*bswrs4)(bus_space_tag_t, BSH_T *, bus_size_t,
				  const u_int32_t *, size_t);
	void		(*bssm1)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int8_t v, size_t);
	void		(*bssm2)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int16_t v, size_t);
	void		(*bssm4)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int32_t v, size_t);
	void		(*bssr1)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int8_t v, size_t);
	void		(*bssr2)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int16_t v, size_t);
	void		(*bssr4)(bus_space_tag_t, BSH_T *, bus_size_t,
				 u_int32_t v, size_t);
} bus_space_handle_t;
#undef BSH_T

void	mac68k_bus_space_handle_swapped(bus_space_tag_t,
		bus_space_handle_t *);
void	mac68k_bus_space_handle_set_stride(bus_space_tag_t,
		bus_space_handle_t *, int);

/*
 *	int bus_space_map(bus_space_tag_t t, bus_addr_t addr,
 *	    bus_size_t size, int flags, bus_space_handle_t *bshp);
 *
 * Map a region of bus space.
 */

#define	BUS_SPACE_MAP_CACHEABLE		0x01
#define	BUS_SPACE_MAP_LINEAR		0x02
#define	BUS_SPACE_MAP_PREFETCHABLE	0x04

int	bus_space_map(bus_space_tag_t, bus_addr_t, bus_size_t,
	    int, bus_space_handle_t *);

/*
 *	void bus_space_unmap(bus_space_tag_t t, bus_space_handle_t bsh,
 *	    bus_size_t size);
 *
 * Unmap a region of bus space.
 */

void	bus_space_unmap(bus_space_tag_t, bus_space_handle_t, bus_size_t);

/*
 *	int bus_space_subregion(bus_space_tag_t t, bus_space_handle_t bsh,
 *	    bus_size_t offset, bus_size_t size, bus_space_handle_t *nbshp);
 *
 * Get a new handle for a subregion of an already-mapped area of bus space.
 */

int	bus_space_subregion(bus_space_tag_t, bus_space_handle_t,
	    bus_size_t, bus_size_t size, bus_space_handle_t *);

/*
 *	int bus_space_alloc(bus_space_tag_t t, bus_addr_t, rstart,
 *	    bus_addr_t rend, bus_size_t size, bus_size_t align,
 *	    bus_size_t boundary, int flags, bus_addr_t *addrp,
 *	    bus_space_handle_t *bshp);
 *
 * Allocate a region of bus space.
 */

int	bus_space_alloc(bus_space_tag_t, bus_addr_t rstart,
	    bus_addr_t rend, bus_size_t size, bus_size_t align,
	    bus_size_t boundary, int cacheable, bus_addr_t *addrp,
	    bus_space_handle_t *bshp);

/*
 *	int bus_space_free(bus_space_tag_t t, bus_space_handle_t bsh,
 *	    bus_size_t size);
 *
 * Free a region of bus space.
 */

void	bus_space_free(bus_space_tag_t, bus_space_handle_t bsh,
	    bus_size_t size);

/*
 *	int mac68k_bus_space_probe(bus_space_tag_t t, bus_space_handle_t bsh,
 *	    bus_size_t offset, int sz);
 *
 * Probe the bus at t/bsh/offset, using sz as the size of the load.
 *
 * This is a machine-dependent extension, and is not to be used by
 * machine-independent code.
 */

int	mac68k_bus_space_probe(bus_space_tag_t,
	    bus_space_handle_t bsh, bus_size_t, int sz);

/*
 *	u_intN_t bus_space_read_N(bus_space_tag_t tag,
 *	    bus_space_handle_t bsh, bus_size_t offset);
 *
 * Read a 1, 2, 4, or 8 byte quantity from bus space
 * described by tag/handle/offset.
 */

u_int8_t mac68k_bsr1(bus_space_tag_t, bus_space_handle_t *, bus_size_t);
u_int8_t mac68k_bsr1_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t);
u_int16_t mac68k_bsr2(bus_space_tag_t, bus_space_handle_t *, bus_size_t);
u_int16_t mac68k_bsr2_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t);
u_int16_t mac68k_bsr2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t);
u_int16_t mac68k_bsrs2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t);
u_int32_t mac68k_bsr4(bus_space_tag_t, bus_space_handle_t *, bus_size_t);
u_int32_t mac68k_bsr4_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t);
u_int32_t mac68k_bsr4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t);
u_int32_t mac68k_bsrs4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t);

#define	bus_space_read_1(t,h,o)	(h).bsr1((t), &(h), (o))
#define	bus_space_read_2(t,h,o)	(h).bsr2((t), &(h), (o))
#define	bus_space_read_4(t,h,o)	(h).bsr4((t), &(h), (o))
#define	bus_space_read_stream_1(t,h,o)	(h).bsrs1((t), &(h), (o))
#define	bus_space_read_stream_2(t,h,o)	(h).bsrs2((t), &(h), (o))
#define	bus_space_read_stream_4(t,h,o)	(h).bsrs4((t), &(h), (o))

/*
 *	void bus_space_read_multi_N(bus_space_tag_t tag,
 *	    bus_space_handle_t bsh, bus_size_t offset, u_intN_t *addr,
 *	    size_t count);
 *
 * Read `count' 1, 2, 4, or 8 byte quantities from bus space
 * described by tag/handle/offset and copy into buffer provided.
 */

void mac68k_bsrm1(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int8_t *, size_t);
void mac68k_bsrm1_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int8_t *, size_t);
void mac68k_bsrm2(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t *, size_t);
void mac68k_bsrm2_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t *, size_t);
void mac68k_bsrm2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t *, size_t);
void mac68k_bsrms2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t *, size_t);
void mac68k_bsrm4(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t *, size_t);
void mac68k_bsrms4(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t *, size_t);
void mac68k_bsrm4_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t *, size_t);
void mac68k_bsrm4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t *, size_t);
void mac68k_bsrms4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t *, size_t);

#if defined(DIAGNOSTIC)
#define	bus_space_read_multi_1(t, h, o, a, c) do {			 \
	if ((c) == 0)							 \
		panic("bus_space_read_multi_1 called with zero count."); \
	(h).bsrm1(t,&(h),o,a,c); } while (0)
#define	bus_space_read_multi_2(t, h, o, a, c) do {			 \
	if ((c) == 0)							 \
		panic("bus_space_read_multi_2 called with zero count."); \
	(h).bsrm2(t,&(h),o,a,c); } while (0)
#define	bus_space_read_multi_4(t, h, o, a, c) do {			 \
	if ((c) == 0)							 \
		panic("bus_space_read_multi_4 called with zero count."); \
	(h).bsrm4(t,&(h),o,a,c); } while (0)
#define	bus_space_read_multi_stream_1(t, h, o, a, c) do {		 \
	if ((c) == 0)							 \
		panic("bus_space_read_multi_stream_1 called with count=0."); \
	(h).bsrms1(t,&(h),o,a,c); } while (0)
#define	bus_space_read_multi_stream_2(t, h, o, a, c) do {		 \
	if ((c) == 0)							 \
		panic("bus_space_read_multi_stream_2 called with count=0."); \
	(h).bsrms2(t,&(h),o,a,c); } while (0)
#define	bus_space_read_multi_stream_4(t, h, o, a, c) do {		 \
	if ((c) == 0)							 \
		panic("bus_space_read_multi_stream_4 called with count=0."); \
	(h).bsrms4(t,&(h),o,a,c); } while (0)
#else
#define	bus_space_read_multi_1(t, h, o, a, c) \
	do { if (c) (h).bsrm1(t, &(h), o, a, c); } while (0)
#define	bus_space_read_multi_2(t, h, o, a, c) \
	do { if (c) (h).bsrm2(t, &(h), o, a, c); } while (0)
#define	bus_space_read_multi_4(t, h, o, a, c) \
	do { if (c) (h).bsrm4(t, &(h), o, a, c); } while (0)
#define	bus_space_read_multi_stream_1(t, h, o, a, c) \
	do { if (c) (h).bsrms1(t, &(h), o, a, c); } while (0)
#define	bus_space_read_multi_stream_2(t, h, o, a, c) \
	do { if (c) (h).bsrms2(t, &(h), o, a, c); } while (0)
#define	bus_space_read_multi_stream_4(t, h, o, a, c) \
	do { if (c) (h).bsrms4(t, &(h), o, a, c); } while (0)
#endif

/*
 *	void bus_space_read_region_N(bus_space_tag_t tag,
 *	    bus_space_handle_t bsh, bus_size_t offset,
 *	    u_intN_t *addr, size_t count);
 *
 * Read `count' 1, 2, 4, or 8 byte quantities from bus space
 * described by tag/handle and starting at `offset' and copy into
 * buffer provided.
 */

void mac68k_bsrr1(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int8_t *, size_t);
void mac68k_bsrr1_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int8_t *, size_t);
void mac68k_bsrr2(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t *, size_t);
void mac68k_bsrr2_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t *, size_t);
void mac68k_bsrr2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t *, size_t);
void mac68k_bsrrs2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t *, size_t);
void mac68k_bsrr4(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t *, size_t);
void mac68k_bsrr4_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t *, size_t);
void mac68k_bsrr4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t *, size_t);
void mac68k_bsrrs4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t *, size_t);

#if defined(DIAGNOSTIC)
#define	bus_space_read_region_1(t, h, o, a, c) do {			  \
	if ((c) == 0)							  \
		panic("bus_space_read_region_1 called with zero count."); \
	(h).bsrr1(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_2(t, h, o, a, c) do {			  \
	if ((c) == 0)							  \
		panic("bus_space_read_region_2 called with zero count."); \
	(h).bsrr2(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_4(t, h, o, a, c) do {			  \
	if ((c) == 0)							  \
		panic("bus_space_read_region_4 called with zero count."); \
	(h).bsrr4(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_stream_1(t, h, o, a, c) do {		  \
	if ((c) == 0)							  \
		panic("bus_space_read_region_stream_1 called with count=0."); \
	(h).bsrrs1(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_stream_2(t, h, o, a, c) do {		  \
	if ((c) == 0)							  \
		 panic("bus_space_read_region_stream_2 called with count=0."); \
	(h).bsrrs2(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_stream_4(t, h, o, a, c) do {		  \
	if ((c) == 0)							  \
		panic("bus_space_read_region_stream_4 called with count=0."); \
	(h).bsrrs4(t,&(h),o,a,c); } while (0)
#else
#define	bus_space_read_region_1(t, h, o, a, c) \
	do { if (c) (h).bsrr1(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_2(t, h, o, a, c) \
	do { if (c) (h).bsrr2(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_4(t, h, o, a, c) \
	do { if (c) (h).bsrr4(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_stream_1(t, h, o, a, c) \
	do { if (c) (h).bsrrs1(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_stream_2(t, h, o, a, c) \
	do { if (c) (h).bsrrs2(t,&(h),o,a,c); } while (0)
#define	bus_space_read_region_stream_4(t, h, o, a, c) \
	do { if (c) (h).bsrrs4(t,&(h),o,a,c); } while (0)
#endif

/*
 *	void bus_space_write_N(bus_space_tag_t tag,
 *	    bus_space_handle_t bsh, bus_size_t offset, u_intN_t value);
 *
 * Write the 1, 2, 4, or 8 byte value `value' to bus space
 * described by tag/handle/offset.
 */

void mac68k_bsw1(bus_space_tag_t, bus_space_handle_t *, bus_size_t, u_int8_t);
void mac68k_bsw1_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int8_t);
void mac68k_bsw2(bus_space_tag_t, bus_space_handle_t *, bus_size_t, u_int16_t);
void mac68k_bsw2_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t);
void mac68k_bsw2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t);
void mac68k_bsws2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t);
void mac68k_bsw4(bus_space_tag_t, bus_space_handle_t *, bus_size_t, u_int32_t);
void mac68k_bsw4_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t);
void mac68k_bsw4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t);
void mac68k_bsws4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t);

#define	bus_space_write_1(t, h, o, v) (h).bsw1(t, &(h), o, v)
#define	bus_space_write_2(t, h, o, v) (h).bsw2(t, &(h), o, v)
#define	bus_space_write_4(t, h, o, v) (h).bsw4(t, &(h), o, v)
#define	bus_space_write_stream_1(t, h, o, v) (h).bsws1(t, &(h), o, v)
#define	bus_space_write_stream_2(t, h, o, v) (h).bsws2(t, &(h), o, v)
#define	bus_space_write_stream_4(t, h, o, v) (h).bsws4(t, &(h), o, v)

/*
 *	void bus_space_write_multi_N(bus_space_tag_t tag,
 *	    bus_space_handle_t bsh, bus_size_t offset, const u_intN_t *addr,
 *	    size_t count);
 *
 * Write `count' 1, 2, 4, or 8 byte quantities from the buffer
 * provided to bus space described by tag/handle/offset.
 */

void mac68k_bswm1(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int8_t *, size_t);
void mac68k_bswm1_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int8_t *, size_t);
void mac68k_bswm2(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int16_t *, size_t);
void mac68k_bswm2_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int16_t *, size_t);
void mac68k_bswm2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int16_t *, size_t);
void mac68k_bswms2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int16_t *, size_t);
void mac68k_bswm4(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int32_t *, size_t);
void mac68k_bswm4_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int32_t *, size_t);
void mac68k_bswm4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int32_t *, size_t);
void mac68k_bswms4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int32_t *, size_t);

#if defined(DIAGNOSTIC)
#define	bus_space_write_multi_1(t, h, o, a, c) do {			  \
	if ((c) == 0)							  \
		panic("bus_space_write_multi_1 called with zero count."); \
	(h).bswm1(t,&(h),o,a,c); } while (0)
#define	bus_space_write_multi_2(t, h, o, a, c) do {			  \
	if ((c) == 0)							  \
		panic("bus_space_write_multi_2 called with zero count."); \
	(h).bswm2(t,&(h),o,a,c); } while (0)
#define	bus_space_write_multi_4(t, h, o, a, c) do {			  \
	if ((c) == 0)							  \
		panic("bus_space_write_multi_4 called with zero count."); \
	(h).bswm4(t,&(h),o,a,c); } while (0)
#define	bus_space_write_multi_stream_1(t, h, o, a, c) do {		  \
	if ((c) == 0)							  \
		panic("bus_space_write_multi_stream_1 called with count=0."); \
	(h).bswms1(t,&(h),o,a,c); } while (0)
#define	bus_space_write_multi_stream_2(t, h, o, a, c) do {		  \
	if ((c) == 0)							  \
		panic("bus_space_write_multi_stream_2 called with count=0."); \
	(h).bswms2(t,&(h),o,a,c); } while (0)
#define	bus_space_write_multi_stream_4(t, h, o, a, c) do {		  \
	if ((c) == 0)							  \
		panic("bus_space_write_multi_stream_4 called with count=0."); \
	(h).bswms4(t,&(h),o,a,c); } while (0)
#else
#define	bus_space_write_multi_1(t, h, o, a, c) \
	do { if (c) (h).bswm1(t, &(h), o, a, c); } while (0)
#define	bus_space_write_multi_2(t, h, o, a, c) \
	do { if (c) (h).bswm2(t, &(h), o, a, c); } while (0)
#define	bus_space_write_multi_4(t, h, o, a, c) \
	do { if (c) (h).bswm4(t, &(h), o, a, c); } while (0)
#define	bus_space_write_multi_stream_1(t, h, o, a, c) \
	do { if (c) (h).bswms1(t, &(h), o, a, c); } while (0)
#define	bus_space_write_multi_stream_2(t, h, o, a, c) \
	do { if (c) (h).bswms2(t, &(h), o, a, c); } while (0)
#define	bus_space_write_multi_stream_4(t, h, o, a, c) \
	do { if (c) (h).bswms4(t, &(h), o, a, c); } while (0)
#endif

/*
 *	void bus_space_write_region_N(bus_space_tag_t tag,
 *	    bus_space_handle_t bsh, bus_size_t offset, const u_intN_t *addr,
 *	    size_t count);
 *
 * Write `count' 1, 2, 4, or 8 byte quantities from the buffer provided
 * to bus space described by tag/handle starting at `offset'.
 */

void mac68k_bswr1(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int8_t *, size_t);
void mac68k_bswr1_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int8_t *, size_t);
void mac68k_bswr2(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int16_t *, size_t);
void mac68k_bswr2_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int16_t *, size_t);
void mac68k_bswr2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int16_t *, size_t);
void mac68k_bswrs2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int16_t *, size_t);
void mac68k_bswr4(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int32_t *, size_t);
void mac68k_bswr4_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int32_t *, size_t);
void mac68k_bswr4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int32_t *, size_t);
void mac68k_bswrs4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	const u_int32_t *, size_t);

#if defined(DIAGNOSTIC)
#define	bus_space_write_region_1(t, h, o, a, c) do {			   \
	if ((c) == 0)							   \
		panic("bus_space_write_region_1 called with zero count."); \
	(h).bswr1(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_2(t, h, o, a, c) do {			   \
	if ((c) == 0)							   \
		panic("bus_space_write_region_2 called with zero count."); \
	(h).bswr2(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_4(t, h, o, a, c) do {			   \
	if ((c) == 0)							   \
		panic("bus_space_write_region_4 called with zero count."); \
	(h).bswr4(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_stream_1(t, h, o, a, c) do {		   \
	if ((c) == 0)							   \
		panic("bus_space_write_region_stream_1 called with count=0."); \
	(h).bswrs1(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_stream_2(t, h, o, a, c) do {		   \
	if ((c) == 0)							   \
		panic("bus_space_write_region_stream_2 called with count=0."); \
	(h).bswrs2(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_stream_4(t, h, o, a, c) do {		   \
	if ((c) == 0)							   \
		panic("bus_space_write_region_stream_4 called with count=0."); \
	(h).bswrs4(t,&(h),o,a,c); } while (0)
#else
#define	bus_space_write_region_1(t, h, o, a, c) \
	do { if (c) (h).bswr1(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_2(t, h, o, a, c) \
	do { if (c) (h).bswr2(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_4(t, h, o, a, c) \
	do { if (c) (h).bswr4(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_stream_1(t, h, o, a, c) \
	do { if (c) (h).bswrs1(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_stream_2(t, h, o, a, c) \
	do { if (c) (h).bswrs2(t,&(h),o,a,c); } while (0)
#define	bus_space_write_region_stream_4(t, h, o, a, c) \
	do { if (c) (h).bswrs4(t,&(h),o,a,c); } while (0)
#endif

/*
 *	void bus_space_set_multi_N(bus_space_tag_t tag,
 *	    bus_space_handle_t bsh, bus_size_t offset, u_intN_t val,
 *	    size_t count);
 *
 * Write the 1, 2, 4, or 8 byte value `val' to bus space described
 * by tag/handle/offset `count' times.
 */

void mac68k_bssm1(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int8_t, size_t);
void mac68k_bssm1_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int8_t, size_t);
void mac68k_bssm2(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t, size_t);
void mac68k_bssm2_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t, size_t);
void mac68k_bssm2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t, size_t);
void mac68k_bssm4(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t, size_t);
void mac68k_bssm4_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t, size_t);
void mac68k_bssm4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t, size_t);

#if defined(DIAGNOSTIC)
#define	bus_space_set_multi_1(t, h, o, val, c) do {			\
	if ((c) == 0)							\
		 panic("bus_space_set_multi_1 called with zero count."); \
	(h).bssm1(t,&(h),o,val,c); } while (0)
#define	bus_space_set_multi_2(t, h, o, val, c) do {			\
	if ((c) == 0)							\
		panic("bus_space_set_multi_2 called with zero count."); \
	(h).bssm2(t,&(h),o,val,c); } while (0)
#define	bus_space_set_multi_4(t, h, o, val, c) do {			\
	if ((c) == 0)							\
		panic("bus_space_set_multi_4 called with zero count."); \
	(h).bssm4(t,&(h),o,val,c); } while (0)
#else
#define	bus_space_set_multi_1(t, h, o, val, c) \
	do { if (c) (h).bssm1(t,&(h),o,val,c); } while (0)
#define	bus_space_set_multi_2(t, h, o, val, c) \
	do { if (c) (h).bssm2(t,&(h),o,val,c); } while (0)
#define	bus_space_set_multi_4(t, h, o, val, c) \
	do { if (c) (h).bssm4(t,&(h),o,val,c); } while (0)
#endif

/*
 *	void bus_space_set_region_N(bus_space_tag_t tag,
 *	    bus_space_handle_t bsh, bus_size_t, u_intN_t val,
 *	    size_t count);
 *
 * Write `count' 1, 2, 4, or 8 byte value `val' to bus space described
 * by tag/handle starting at `offset'.
 */

void mac68k_bssr1(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int8_t, size_t);
void mac68k_bssr1_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int8_t, size_t);
void mac68k_bssr2(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t, size_t);
void mac68k_bssr2_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t, size_t);
void mac68k_bssr2_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int16_t, size_t);
void mac68k_bssr4(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t, size_t);
void mac68k_bssr4_swap(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t, size_t);
void mac68k_bssr4_gen(bus_space_tag_t, bus_space_handle_t *, bus_size_t,
	u_int32_t, size_t);

#if defined(DIAGNOSTIC)
#define	bus_space_set_region_1(t, h, o, val, c) do {			 \
	if ((c) == 0)							 \
		panic("bus_space_set_region_1 called with zero count."); \
	(h).bssr1(t,&(h),o,val,c); } while (0)
#define	bus_space_set_region_2(t, h, o, val, c) do {			 \
	if ((c) == 0)							 \
		panic("bus_space_set_region_2 called with zero count."); \
	(h).bssr2(t,&(h),o,val,c); } while (0)
#define	bus_space_set_region_4(t, h, o, val, c) do {			 \
	if ((c) == 0)							 \
		panic("bus_space_set_region_4 called with zero count."); \
	(h).bssr4(t,&(h),o,val,c); } while (0)
#else
#define	bus_space_set_region_1(t, h, o, val, c) \
	do { if (c) (h).bssr1(t,&(h),o,val,c); } while (0)
#define	bus_space_set_region_2(t, h, o, val, c) \
	do { if (c) (h).bssr2(t,&(h),o,val,c); } while (0)
#define	bus_space_set_region_4(t, h, o, val, c) \
	do { if (c) (h).bssr4(t,&(h),o,val,c); } while (0)
#endif

/*
 *	void bus_space_copy_N(bus_space_tag_t tag,
 *	    bus_space_handle_t bsh1, bus_size_t off1,
 *	    bus_space_handle_t bsh2, bus_size_t off2, size_t count);
 *
 * Copy `count' 1, 2, 4, or 8 byte values from bus space starting
 * at tag/bsh1/off1 to bus space starting at tag/bsh2/off2.
 */

#define	__MAC68K_copy_region_N(BYTES)					\
static __inline void __CONCAT(bus_space_copy_region_,BYTES)		\
	(bus_space_tag_t,						\
	    bus_space_handle_t, bus_size_t,				\
	    bus_space_handle_t, bus_size_t,				\
	    bus_size_t);						\
									\
static __inline void							\
__CONCAT(bus_space_copy_region_,BYTES)(					\
	bus_space_tag_t t,						\
	bus_space_handle_t h1,						\
	bus_size_t o1,							\
	bus_space_handle_t h2,						\
	bus_size_t o2,							\
	bus_size_t c)							\
{									\
	bus_size_t o;							\
									\
	if ((h1.base + o1) >= (h2.base + o2)) {				\
		/* src after dest: copy forward */			\
		for (o = 0; c != 0; c--, o += BYTES)			\
			__CONCAT(bus_space_write_,BYTES)(t, h2, o2 + o,	\
			    __CONCAT(bus_space_read_,BYTES)(t, h1, o1 + o)); \
	} else {							\
		/* dest after src: copy backwards */			\
		for (o = (c - 1) * BYTES; c != 0; c--, o -= BYTES)	\
			__CONCAT(bus_space_write_,BYTES)(t, h2, o2 + o,	\
			    __CONCAT(bus_space_read_,BYTES)(t, h1, o1 + o)); \
	}								\
}
__MAC68K_copy_region_N(1)
__MAC68K_copy_region_N(2)
__MAC68K_copy_region_N(4)

#undef __MAC68K_copy_region_N

/*
 * Bus read/write barrier methods.
 *
 *	void bus_space_barrier(bus_space_tag_t tag, bus_space_handle_t bsh,
 *	    bus_size_t offset, bus_size_t len, int flags);
 *
 * Note: the 680x0 does not currently require barriers, but we must
 * provide the flags to MI code.
 */
#define	bus_space_barrier(t, h, o, l, f)	\
	((void)((void)(t), (void)(h), (void)(o), (void)(l), (void)(f)))
#define	BUS_SPACE_BARRIER_READ	0x01		/* force read barrier */
#define	BUS_SPACE_BARRIER_WRITE	0x02		/* force write barrier */

/*
 *	void *bus_space_vaddr(bus_space_tag_t, bus_space_handle_t);
 *
 * Get the kernel virtual address for the mapped bus space.
 */
#define	bus_space_vaddr(t, h)	((void)(t), (void *)(h.base))

#define BUS_SPACE_ALIGNED_POINTER(p, t) ALIGNED_POINTER(p, t)

#include <m68k/bus_dma.h>

#endif /* _MAC68K_BUS_H_ */