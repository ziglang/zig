/*-
 * Copyright (c) 2005 The FreeBSD Foundation.
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Derived in part from NetBSD's bus.h files by (alphabetically):
 *	Christopher G. Demetriou
 *	Charles M. Hannum
 *	Jason Thorpe
 *	The NetBSD Foundation.
 */

#ifndef AMD64_INCLUDE__BUS_H
#define AMD64_INCLUDE__BUS_H

/*
 * Bus address and size types
 */
typedef uint64_t bus_addr_t;
typedef uint64_t bus_size_t;

/*
 * Access methods for bus resources and address space.
 */
typedef	uint64_t bus_space_tag_t;
typedef	uint64_t bus_space_handle_t;

#endif /* AMD64_INCLUDE__BUS_H */