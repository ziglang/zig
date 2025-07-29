/*-
 * Copyright (c) 2021 M. Warner Losh <imp@FreeBSD.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

/*
 * A mostly Linux/glibc-compatible byteswap.h
 */

#ifndef _BYTESWAP_H_
#define _BYTESWAP_H_

/*
 * sys/_endian.h brings in the shared interfaces between BSD's sys/endian.h, and
 * glibc's endian.h. However, we need to include it here to get the
 * __bswap{16,32,64} definitions that we use. sys/_endian.h has been consturcted to
 * be compatible with including <endian.h>, <byteswap.h> or both in either order,
 * as well as providing the BSD the bulk of sys/endian.h functionality.
 */
#include <sys/_endian.h>

/*
 * glibc's <byteswap.h> defines the bswap_* and __bswap_* macros below. Most
 * software uses either just <sys/endian.h>, or both <endian.h> and
 * <byteswap.h>. However, one can't define bswap16, etc in <endian.h> because
 * several software packages will define them only when they detect <endian.h>
 * is included (but not when sys/endian.h is included). Defining bswap16, etc
 * here causes compilation errors for those packages. <endian.h> and
 * <byteswap.h> need to be paired together, with the below defines here, for
 * the highest level of glibc compatibility.
 */
#define __bswap_16(x) __bswap16(x)
#define __bswap_32(x) __bswap32(x)
#define __bswap_64(x) __bswap64(x)

#define bswap_16(x) __bswap16(x)
#define bswap_32(x) __bswap32(x)
#define bswap_64(x) __bswap64(x)

#endif /* _BYTESWAP_H_ */