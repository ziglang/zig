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

#ifndef I386_INCLUDE__BUS_H
#define I386_INCLUDE__BUS_H

/*
 * Bus address and size types
 */
#ifdef PAE
typedef uint64_t bus_addr_t;
#else
typedef uint32_t bus_addr_t;
#endif
typedef uint32_t bus_size_t;

/*
 * Access methods for bus resources and address space.
 */
typedef	int bus_space_tag_t;
typedef	u_int bus_space_handle_t;

#endif /* I386_INCLUDE__BUS_H */