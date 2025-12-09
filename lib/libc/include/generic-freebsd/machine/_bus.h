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

#ifndef _MACHINE__BUS_H_
#define	_MACHINE__BUS_H_

/*
 * Addresses (in bus space).
 */
typedef u_long bus_addr_t;
typedef u_long bus_size_t;

/*
 * Access methods for bus space.
 */
typedef u_long bus_space_handle_t;
typedef struct bus_space *bus_space_tag_t;

#endif /* !_MACHINE__BUS_H_ */