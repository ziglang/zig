/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2025 The FreeBSD Foundation
 * All rights reserved.
 *
 * This software were developed by Konstantin Belousov <kib@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
 */

#ifndef _SYS__UEXTERROR_H_
#define	_SYS__UEXTERROR_H_

#include <sys/_types.h>

struct uexterror {
	__uint32_t ver;
	__uint32_t error;
	__uint32_t cat;
	__uint32_t src_line;
	__uint32_t flags;
	__uint32_t rsrv0;
	__uint64_t p1;
	__uint64_t p2;
	__uint64_t rsrv1[4];
	char msg[128];
};

#endif