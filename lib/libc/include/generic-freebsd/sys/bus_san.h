/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Andrew Turner
 * Copyright (c) 2021 The FreeBSD Foundation
 *
 * This software was developed by SRI International and the University of
 * Cambridge Computer Laboratory (Department of Computer Science and
 * Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
 * DARPA SSITH research programme.
 *
 * Portions of this software were written by Mark Johnston under sponsorship by
 * the FreeBSD Foundation.
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

#ifndef _SYS_BUS_SAN_H_
#define	_SYS_BUS_SAN_H_

#ifndef _MACHINE_BUS_H_
#error do not include this header, use machine/bus.h
#endif

#define	BUS_SAN_MULTI(sp, rw, width, type)				\
	void sp##_bus_space_##rw##_multi_##width(bus_space_tag_t, 	\
	    bus_space_handle_t, bus_size_t, type *, bus_size_t);	\
	void sp##_bus_space_##rw##_multi_stream_##width(bus_space_tag_t, \
	    bus_space_handle_t, bus_size_t, type *, bus_size_t);	\
	void sp##_bus_space_##rw##_region_##width(bus_space_tag_t,	\
	    bus_space_handle_t, bus_size_t, type *, bus_size_t);	\
	void sp##_bus_space_##rw##_region_stream_##width(bus_space_tag_t, \
	    bus_space_handle_t, bus_size_t, type *, bus_size_t)

#define	BUS_SAN_READ(sp, width, type)					\
	type sp##_bus_space_read_##width(bus_space_tag_t, 		\
	    bus_space_handle_t, bus_size_t);				\
	type sp##_bus_space_read_stream_##width(bus_space_tag_t,	\
	    bus_space_handle_t, bus_size_t);				\
	BUS_SAN_MULTI(sp, read, width, type)

#define	BUS_SAN_WRITE(sp, width, type)					\
	void sp##_bus_space_write_##width(bus_space_tag_t, 		\
	    bus_space_handle_t, bus_size_t, type);			\
	void sp##_bus_space_write_stream_##width(bus_space_tag_t,	\
	    bus_space_handle_t, bus_size_t, type);			\
	BUS_SAN_MULTI(sp, write, width, const type)

#define	BUS_SAN_SET(sp, width, type)					\
	void sp##_bus_space_set_multi_##width(bus_space_tag_t,		\
	    bus_space_handle_t, bus_size_t, type, bus_size_t);		\
	void sp##_bus_space_set_multi_stream_##width(bus_space_tag_t,	\
	    bus_space_handle_t, bus_size_t, type, bus_size_t);		\
	void sp##_bus_space_set_region_##width(bus_space_tag_t,		\
	    bus_space_handle_t, bus_size_t, type, bus_size_t);		\
	void sp##_bus_space_set_region_stream_##width(bus_space_tag_t,	\
	    bus_space_handle_t, bus_size_t, type, bus_size_t)

#define	BUS_SAN_COPY(sp, width, type)					\
	void sp##_bus_space_copy_region_##width(bus_space_tag_t,	\
	    bus_space_handle_t,	bus_size_t, bus_space_handle_t,		\
	    bus_size_t, bus_size_t);					\
	void sp##_bus_space_copy_region_stream_##width(bus_space_tag_t, \
	    bus_space_handle_t,	bus_size_t, bus_space_handle_t,		\
	    bus_size_t, bus_size_t);

#define	BUS_SAN_PEEK(sp, width, type)					\
	int sp##_bus_space_peek_##width(bus_space_tag_t, 		\
	    bus_space_handle_t, bus_size_t, type *);

#define	BUS_SAN_POKE(sp, width, type)					\
	int sp##_bus_space_poke_##width(bus_space_tag_t, 		\
	    bus_space_handle_t, bus_size_t, type);

#define	_BUS_SAN_MISC(sp)						\
	int sp##_bus_space_map(bus_space_tag_t, bus_addr_t, bus_size_t,	\
	    int, bus_space_handle_t *);					\
	void sp##_bus_space_unmap(bus_space_tag_t, bus_space_handle_t,	\
	    bus_size_t);						\
	int sp##_bus_space_subregion(bus_space_tag_t, bus_space_handle_t,\
	    bus_size_t, bus_size_t, bus_space_handle_t *);		\
	int sp##_bus_space_alloc(bus_space_tag_t, bus_addr_t, bus_addr_t,\
	    bus_size_t, bus_size_t, bus_size_t, int, bus_addr_t *,	\
	    bus_space_handle_t *);					\
	void sp##_bus_space_free(bus_space_tag_t, bus_space_handle_t,	\
	    bus_size_t);						\
	void sp##_bus_space_barrier(bus_space_tag_t, bus_space_handle_t,\
	    bus_size_t, bus_size_t, int);

#define	BUS_SAN_MISC(sp)						\
	_BUS_SAN_MISC(sp)

#define	_BUS_SAN_FUNCS(sp, width, type)					\
	BUS_SAN_READ(sp, width, type);					\
	BUS_SAN_WRITE(sp, width, type);					\
	BUS_SAN_SET(sp, width, type);					\
	BUS_SAN_COPY(sp, width, type)					\
	BUS_SAN_PEEK(sp, width, type);					\
	BUS_SAN_POKE(sp, width, type)

#define	BUS_SAN_FUNCS(width, type)					\
	_BUS_SAN_FUNCS(SAN_INTERCEPTOR_PREFIX, width, type)

BUS_SAN_FUNCS(1, uint8_t);
BUS_SAN_FUNCS(2, uint16_t);
BUS_SAN_FUNCS(4, uint32_t);
BUS_SAN_FUNCS(8, uint64_t);
BUS_SAN_MISC(SAN_INTERCEPTOR_PREFIX);

#ifndef SAN_RUNTIME

#define	BUS_SAN(func)							\
	__CONCAT(SAN_INTERCEPTOR_PREFIX, __CONCAT(_bus_space_, func))

#define	bus_space_map			BUS_SAN(map)
#define	bus_space_unmap			BUS_SAN(unmap)
#define	bus_space_subregion		BUS_SAN(subregion)
#define	bus_space_alloc			BUS_SAN(alloc)
#define	bus_space_free			BUS_SAN(free)
#define	bus_space_barrier		BUS_SAN(barrier)

#define	bus_space_read_1		BUS_SAN(read_1)
#define	bus_space_read_stream_1		BUS_SAN(read_stream_1)
#define	bus_space_read_multi_1		BUS_SAN(read_multi_1)
#define	bus_space_read_multi_stream_1	BUS_SAN(read_multi_stream_1)
#define	bus_space_read_region_1		BUS_SAN(read_region_1)
#define	bus_space_read_region_stream_1	BUS_SAN(read_region_stream_1)
#define	bus_space_write_1		BUS_SAN(write_1)
#define	bus_space_write_stream_1	BUS_SAN(write_stream_1)
#define	bus_space_write_multi_1		BUS_SAN(write_multi_1)
#define	bus_space_write_multi_stream_1	BUS_SAN(write_multi_stream_1)
#define	bus_space_write_region_1	BUS_SAN(write_region_1)
#define	bus_space_write_region_stream_1	BUS_SAN(write_region_stream_1)
#define	bus_space_set_multi_1		BUS_SAN(set_multi_1)
#define	bus_space_set_multi_stream_1	BUS_SAN(set_multi_stream_1)
#define	bus_space_set_region_1		BUS_SAN(set_region_1)
#define	bus_space_set_region_stream_1	BUS_SAN(set_region_stream_1)
#define	bus_space_copy_multi_1		BUS_SAN(copy_multi_1)
#define	bus_space_copy_multi_stream_1	BUS_SAN(copy_multi_stream_1)
#define	bus_space_poke_1		BUS_SAN(poke_1)
#define	bus_space_peek_1		BUS_SAN(peek_1)

#define	bus_space_read_2		BUS_SAN(read_2)
#define	bus_space_read_stream_2		BUS_SAN(read_stream_2)
#define	bus_space_read_multi_2		BUS_SAN(read_multi_2)
#define	bus_space_read_multi_stream_2	BUS_SAN(read_multi_stream_2)
#define	bus_space_read_region_2		BUS_SAN(read_region_2)
#define	bus_space_read_region_stream_2	BUS_SAN(read_region_stream_2)
#define	bus_space_write_2		BUS_SAN(write_2)
#define	bus_space_write_stream_2	BUS_SAN(write_stream_2)
#define	bus_space_write_multi_2		BUS_SAN(write_multi_2)
#define	bus_space_write_multi_stream_2	BUS_SAN(write_multi_stream_2)
#define	bus_space_write_region_2	BUS_SAN(write_region_2)
#define	bus_space_write_region_stream_2	BUS_SAN(write_region_stream_2)
#define	bus_space_set_multi_2		BUS_SAN(set_multi_2)
#define	bus_space_set_multi_stream_2	BUS_SAN(set_multi_stream_2)
#define	bus_space_set_region_2		BUS_SAN(set_region_2)
#define	bus_space_set_region_stream_2	BUS_SAN(set_region_stream_2)
#define	bus_space_copy_multi_2		BUS_SAN(copy_multi_2)
#define	bus_space_copy_multi_stream_2	BUS_SAN(copy_multi_stream_2)
#define	bus_space_poke_2		BUS_SAN(poke_2)
#define	bus_space_peek_2		BUS_SAN(peek_2)

#define	bus_space_read_4		BUS_SAN(read_4)
#define	bus_space_read_stream_4		BUS_SAN(read_stream_4)
#define	bus_space_read_multi_4		BUS_SAN(read_multi_4)
#define	bus_space_read_multi_stream_4	BUS_SAN(read_multi_stream_4)
#define	bus_space_read_region_4		BUS_SAN(read_region_4)
#define	bus_space_read_region_stream_4	BUS_SAN(read_region_stream_4)
#define	bus_space_write_4		BUS_SAN(write_4)
#define	bus_space_write_stream_4	BUS_SAN(write_stream_4)
#define	bus_space_write_multi_4		BUS_SAN(write_multi_4)
#define	bus_space_write_multi_stream_4	BUS_SAN(write_multi_stream_4)
#define	bus_space_write_region_4	BUS_SAN(write_region_4)
#define	bus_space_write_region_stream_4	BUS_SAN(write_region_stream_4)
#define	bus_space_set_multi_4		BUS_SAN(set_multi_4)
#define	bus_space_set_multi_stream_4	BUS_SAN(set_multi_stream_4)
#define	bus_space_set_region_4		BUS_SAN(set_region_4)
#define	bus_space_set_region_stream_4	BUS_SAN(set_region_stream_4)
#define	bus_space_copy_multi_4		BUS_SAN(copy_multi_4)
#define	bus_space_copy_multi_stream_4	BUS_SAN(copy_multi_stream_4)
#define	bus_space_poke_4		BUS_SAN(poke_4)
#define	bus_space_peek_4		BUS_SAN(peek_4)

#define	bus_space_read_8		BUS_SAN(read_8)
#define	bus_space_read_stream_8		BUS_SAN(read_stream_8)
#define	bus_space_read_multi_8		BUS_SAN(read_multi_8)
#define	bus_space_read_multi_stream_8	BUS_SAN(read_multi_stream_8)
#define	bus_space_read_region_8		BUS_SAN(read_region_8)
#define	bus_space_read_region_stream_8	BUS_SAN(read_region_stream_8)
#define	bus_space_write_8		BUS_SAN(write_8)
#define	bus_space_write_stream_8	BUS_SAN(write_stream_8)
#define	bus_space_write_multi_8		BUS_SAN(write_multi_8)
#define	bus_space_write_multi_stream_8	BUS_SAN(write_multi_stream_8)
#define	bus_space_write_region_8	BUS_SAN(write_region_8)
#define	bus_space_write_region_stream_8	BUS_SAN(write_region_stream_8)
#define	bus_space_set_multi_8		BUS_SAN(set_multi_8)
#define	bus_space_set_multi_stream_8	BUS_SAN(set_multi_stream_8)
#define	bus_space_set_region_8		BUS_SAN(set_region_8)
#define	bus_space_set_region_stream_8	BUS_SAN(set_region_stream_8)
#define	bus_space_copy_multi_8		BUS_SAN(copy_multi_8)
#define	bus_space_copy_multi_stream_8	BUS_SAN(copy_multi_stream_8)
#define	bus_space_poke_8		BUS_SAN(poke_8)
#define	bus_space_peek_8		BUS_SAN(peek_8)

#endif /* !SAN_RUNTIME */

#endif /* !_SYS_BUS_SAN_H_ */