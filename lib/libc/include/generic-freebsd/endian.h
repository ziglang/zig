/*-
 * Copyright (c) 2021 M. Warner Losh <imp@FreeBSD.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

/*
 * A mostly Linux/glibc-compatible endian.h
 */

#ifndef _ENDIAN_H_
#define _ENDIAN_H_

/*
 * FreeBSD's sys/_endian.h is very close to the interface provided on Linux by
 * glibc's endian.h.
 */
#include <sys/_endian.h>

/*
 * glibc uses double underscore for these symbols. Define these unconditionally.
 * The compiler defines __BYTE_ORDER__ these days, so we don't do anything
 * with that since sys/endian.h defines _BYTE_ORDER based on it.
 */
#define __BIG_ENDIAN		_BIG_ENDIAN
#define __BYTE_ORDER		_BYTE_ORDER
#define __LITTLE_ENDIAN		_LITTLE_ENDIAN
#define __PDP_ENDIAN		_PDP_ENDIAN

/*
 * FreeBSD's sys/endian.h and machine/endian.h doesn't define a separate
 * byte order for floats. Use the host non-float byte order.
 */
#define __FLOAT_WORD_ORDER	_BYTE_ORDER

/*
 * We don't define BIG_ENDI, LITTLE_ENDI, HIGH_HALF and LOW_HALF macros that
 * glibc's endian.h defines since those appear to be internal to glibc.
 * We also don't try to emulate the various helper macros that glibc uses to
 * limit namespace visibility.
 */

#endif /* _ENDIAN_H_ */