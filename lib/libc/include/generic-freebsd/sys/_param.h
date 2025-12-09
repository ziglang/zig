/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 */

#ifndef _SYS__PARAM_H_
#define _SYS__PARAM_H_

#define NBBY	8		/* number of bits in a byte */
#define NBPW	sizeof(int)	/* number of bytes per word (integer) */

/*
 * Macros for counting and rounding.
 */
#define	nitems(x)	(sizeof((x)) / sizeof((x)[0]))
#ifndef howmany
#define howmany(x, y)	(((x)+((y)-1))/(y))
#endif
#define	rounddown(x, y)	(((x)/(y))*(y))
#define	rounddown2(x, y) __align_down(x, y) /* if y is power of two */
#define	roundup(x, y)	((((x)+((y)-1))/(y))*(y))  /* to any y */
#define	roundup2(x, y)	__align_up(x, y) /* if y is powers of two */
#define powerof2(x)	((((x)-1)&(x))==0)

#endif /* _SYS__PARAM_H_ */