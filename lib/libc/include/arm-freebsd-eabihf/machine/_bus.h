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

#ifndef ARM_INCLUDE__BUS_H
#define ARM_INCLUDE__BUS_H

/*
 * Addresses (in bus space).
 */
typedef u_long bus_addr_t;
typedef u_long bus_size_t;

/*
 * Access methods for bus space.
 */
typedef struct bus_space *bus_space_tag_t;
typedef u_long bus_space_handle_t;

#endif /* ARM_INCLUDE__BUS_H */