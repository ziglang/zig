/*	$NetBSD: mlxio.h,v 1.4 2017/10/28 06:27:32 riastradh Exp $	*/

/*-
 * Copyright (c) 1999 Michael Smith
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * from FreeBSD: mlxio.h,v 1.1.2.2 2000/04/24 19:40:49 msmith Exp
 */

#ifndef _IC_MLXIO_H_
#define	_IC_MLXIO_H_

#include <sys/types.h>
#include <sys/ioccom.h>

/*
 * System Disk ioctls
 */

/* system disk status values */
#define MLX_SYSD_ONLINE		0x03
#define MLX_SYSD_CRITICAL	0x04
#define MLX_SYSD_OFFLINE	0xff

#define MLXD_STATUS		_IOR('M', 100, int)
#define MLXD_CHECKASYNC		_IOR('M', 101, int)
#define MLXD_DETACH		_IOW('M', 102, int)

/*
 * Controller ioctls
 */
struct mlx_pause {
	int		mp_which;
#define MLX_PAUSE_ALL		0xff
#define MLX_PAUSE_CANCEL	0x00
	int		mp_when;
	int		mp_howlong;
};

struct mlx_usercommand {
	size_t		mu_datasize;	/* size of buffer */
	void		*mu_buf;	/* user address of buffer */
	int		mu_bufptr;	/* offset into command m/b for PA */
	int		mu_bufdir;	/* transfer is to controller */
	u_int16_t	mu_status;	/* command status returned */
	u_int8_t	mu_command[16];	/* command mailbox contents */
};
#define	MU_XFER_IN	0x01
#define	MU_XFER_OUT	0x02
#define	MU_XFER_MASK	0x03

struct mlx_rebuild_request {
	int		rr_channel;
	int		rr_target;
	int		rr_status;
};

struct mlx_rebuild_status {
	u_int16_t	rs_code;
#define MLX_REBUILDSTAT_REBUILDCHECK	0x0000
#define MLX_REBUILDSTAT_ADDCAPACITY	0x0400
#define MLX_REBUILDSTAT_ADDCAPACITYINIT	0x0500
#define MLX_REBUILDSTAT_IDLE		0xffff
	u_int16_t	rs_drive;
	int		rs_size;
	int		rs_remaining;
};

struct mlx_cinfo {
	u_int		ci_iftype;
	u_int		ci_nchan;
	u_int		ci_max_sg;
	u_int		ci_max_commands;
	u_int		ci_mem_size;
	u_int8_t	ci_firmware_id[4];
	u_int8_t	ci_hardware_id;
	u_int8_t	ci_pad[3];
};

#define MLX_RESCAN_DRIVES	_IO('M', 0)
#define MLX_PAUSE_CHANNEL	_IOW('M', 1, struct mlx_pause)
#define MLX_COMMAND		_IOWR('M', 2, struct mlx_usercommand)
#define MLX_REBUILDASYNC	_IOWR('M', 3, struct mlx_rebuild_request)
#define MLX_REBUILDSTAT		_IOR('M', 4, struct mlx_rebuild_status)
#define MLX_GET_SYSDRIVE	_IOWR('M', 5, int)
#define	MLX_GET_CINFO		_IOR('M', 6, struct mlx_cinfo)

#endif	/* !_IC_MLXIO_H_ */