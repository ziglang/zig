/*	$NetBSD: spi_io.h,v 1.1 2019/02/23 10:43:25 mlelstv Exp $	*/

/*
 * Copyright (c) 2019 Michael van Elst
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
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _DEV_SPI_SPI_IO_H_
#define	_DEV_SPI_SPI_IO_H_

#include <sys/types.h>
#include <sys/ioccom.h>
#include <sys/uio.h>

typedef struct spi_ioctl_configure {
	int sic_addr;
	int sic_mode;
	int sic_speed;
} spi_ioctl_configure_t;

typedef struct spi_ioctl_transfer {
	int sit_addr;
	const void *sit_send;
	size_t sit_sendlen;
	void *sit_recv;
	size_t sit_recvlen;
} spi_ioctl_transfer_t;

#define	SPI_IOCTL_CONFIGURE		_IOW('S', 0, spi_ioctl_configure_t)
#define	SPI_IOCTL_TRANSFER		_IOW('S', 1, spi_ioctl_transfer_t)

#endif /* _DEV_SPI_SPI_IO_H_ */