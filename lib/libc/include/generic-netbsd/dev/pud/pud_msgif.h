/*	$NetBSD: pud_msgif.h,v 1.4 2007/11/28 16:59:02 pooka Exp $	*/

/*
 * Copyright (c) 2007  Antti Kantee.  All Rights Reserved.
 *
 * Development of this software was supported by the
 * Research Foundation of Helsinki University of Technology
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _DEV_PUD_PUDMSGIF_H_
#define _DEV_PUD_PUDMSGIF_H_

#include <dev/putter/putter.h>

struct pud_req {
	struct putter_hdr	pdr_pth;

	dev_t			pdr_dev;

	pid_t			pdr_pid;
	lwpid_t			pdr_lid;

	int			pdr_reqclass;
	int			pdr_reqtype;

	uint64_t		pdr_reqid;
	int			pdr_rv;

	size_t			pdr_len;
	uint8_t			pdr_data[0];
};

#define PUD_REQ_CDEV	1
#define PUD_REQ_BDEV	2
#define PUD_REQ_CONF	3

struct pud_register {
	dev_t	pm_dev;
};

#define pud_creq_open pud_req_openclose
#define pud_creq_close pud_req_openclose
struct pud_req_openclose {
	struct pud_req	pm_pdr;

	int		pm_flags;
	int		pm_fmt;
};

#define pud_creq_read pud_req_readwrite
#define pud_creq_write pud_req_readwrite
struct pud_req_readwrite {
	struct pud_req	pm_pdr;

	off_t		pm_offset;
	size_t		pm_resid;

	uint8_t		pm_data[0];
};

struct pud_req_ioctl {
	struct pud_req	pm_pdr;

	u_long		pm_iocmd;
	int		pm_flag;	/* XXX: I feel like a cargo cult */

	uint8_t		pm_data[0];
};

#define PUD_DEVNAME_MAX 31
struct pud_conf_reg {
	struct pud_req	pm_pdr;

	int		pm_version;
	dev_t		pm_regdev;
	int		pm_flags;
	char		pm_devname[PUD_DEVNAME_MAX+1];
};
#define PUD_CONFFLAG_BDEV	1

#define PUD_DEVELVERSION	0x80000000
#define PUD_VERSION		1

enum {
	PUD_CDEV_OPEN,	PUD_CDEV_CLOSE,	PUD_CDEV_READ,	PUD_CDEV_WRITE,
	PUD_CDEV_IOCTL,	PUD_CDEV_POLL,	PUD_CDEV_MMAP,	PUD_CDEV_KQFILTER,
	PUD_CDEV_STOP,	PUD_CDEV_TTY,
};

enum {
	PUD_BDEV_OPEN,	PUD_BDEV_CLOSE, PUD_BDEV_STRATREAD, PUD_BDEV_STRATWRITE,
	PUD_BDEV_IOCTL,	PUD_BDEV_DUMP,	PUD_BDEV_PSIZE,
};

enum {
	PUD_CONF_REG,	PUD_CONF_DEREG,	PUD_CONF_MMAP,
};

#endif /* _DEV_PUD_PUDMSGIF_H_ */