/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2025 The FreeBSD Foundation
 * All rights reserved.
 *
 * This software were developed by Konstantin Belousov <kib@FreeBSD.org>
 * under sponsorship from the FreeBSD Foundation.
 */

#ifndef _SYS__EXTERR_H_
#define	_SYS__EXTERR_H_

#include <sys/_types.h>

struct kexterr {
	int error;
	const char *msg;
	__uint64_t p1;
	__uint64_t p2;
	unsigned cat;
	unsigned src_line;
};

#endif