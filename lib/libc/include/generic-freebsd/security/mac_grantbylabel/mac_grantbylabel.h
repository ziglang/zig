/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2018-2023, Juniper Networks, Inc.
 * All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef	_SECURITY_MAC_GRANTBYLABEL_H
#define	_SECURITY_MAC_GRANTBYLABEL_H

#include <security/mac_veriexec/mac_veriexec.h>

#define	MAC_GRANTBYLABEL_NAME	"mac_grantbylabel"

/* the bits we use to represent tokens */
#define GBL_EMPTY	(1<<0)
#define GBL_BIND	(1<<1)
#define GBL_IPC		(1<<2)
#define GBL_NET		(1<<3)
#define GBL_PROC	(1<<4)
#define GBL_RTSOCK	(1<<5)
#define GBL_SYSCTL	(1<<6)
#define GBL_VACCESS	(1<<7)
#define GBL_VERIEXEC	(1<<8)
#define GBL_KMEM	(1<<9)
#define GBL_MAX		9

/* this should suffice for now */
typedef uint32_t	gbl_label_t;

#define MAC_GRANTBYLABEL_FETCH_GBL	1
#define MAC_GRANTBYLABEL_FETCH_PID_GBL	2

struct mac_grantbylabel_fetch_gbl_args {
	union {
		int	fd;
		pid_t	pid;
	} u;
	gbl_label_t	gbl;
};

#endif