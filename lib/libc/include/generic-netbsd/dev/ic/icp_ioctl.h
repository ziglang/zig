/*	$NetBSD: icp_ioctl.h,v 1.7 2017/10/28 06:27:32 riastradh Exp $	*/

/*
 *       Copyright (c) 2000-03 Intel Corporation
 *       All Rights Reserved
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions, and the following disclaimer,
 *    without modification, immediately at the beginning of the file.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * ioctl interface to ICP-Vortex RAID controllers.  Facilitates use of
 * ICP's configuration tools.
 */

#ifndef _DEV_IC_ICP_IOCTL_H_
#define	_DEV_IC_ICP_IOCTL_H_

#include <sys/cdefs.h>
#include <sys/types.h>
#include <sys/ioccom.h>

#include <dev/ic/icpreg.h>

#define	GDT_SCRATCH_SZ	3072	/* 3KB scratch buffer */

/* general ioctl */
typedef struct gdt_ucmd {
	u_int16_t	io_node;
	u_int16_t	service;
	u_int32_t	timeout;
	u_int16_t	status;
	u_int32_t	info;

	struct {
		u_int32_t	cmd_boardnode;
		u_int32_t	cmd_cmdindex;
		u_int16_t	cmd_opcode;

		union {
			struct icp_rawcmd rc;
			struct icp_ioctlcmd ic;
			struct icp_cachecmd cc;
		} cmd_packet;
	} __packed command;

	u_int8_t	data[GDT_SCRATCH_SZ];
} __packed gdt_ucmd_t;
#define	GDT_IOCTL_GENERAL	_IOWR('J', 0, gdt_ucmd_t)

/* get driver version */
#define	GDT_IOCTL_DRVERS	_IOR('J', 1, int)

/* get controller type */
typedef struct gdt_ctrt {
	u_int16_t	io_node;
	u_int16_t	oem_id;
	u_int16_t	type;
	u_int32_t	info;
	u_int8_t	access;
	u_int8_t	remote;
	u_int16_t	ext_type;
	u_int16_t	device_id;
	u_int16_t	sub_device_id;
} __packed gdt_ctrt_t;
#define	GDT_IOCTL_CTRTYPE	_IOWR('J', 2, gdt_ctrt_t)

/* get OS version */
typedef struct gdt_osv {
	u_int8_t	oscode;
	u_int8_t	version;
	u_int8_t	subversion;
	u_int16_t	revision;
	char		name[64];
} __packed gdt_osv_t;
#define	GDT_IOCTL_OSVERS	_IOR('J', 3, gdt_osv_t)

/* get controller count */
#define	GDT_IOCTL_CTRCNT	_IOR('J', 5, int)

/* 6 -- lock host drive? */
/* 7 -- lock channel? */

/* get event */
#define	GDT_ES_ASYNC		1
#define	GDT_ES_DRIVER		2
#define	GDT_ES_TEST		3
#define	GDT_ES_SYNC		4
typedef struct {
	u_int16_t	size;		/* size of structure */
	union {
		char		stream[16];
		struct {
			u_int16_t	ionode;
			u_int16_t	service;
			u_int32_t	index;
		} __packed driver;
		struct {
			u_int16_t	ionode;
			u_int16_t	service;
			u_int16_t	status;
			u_int32_t	info;
			u_int8_t	scsi_coord[3];
		} __packed async;
		struct {
			u_int16_t	ionode;
			u_int16_t	service;
			u_int16_t	status;
			u_int32_t	info;
			u_int16_t	hostdrive;
			u_int8_t	scsi_coord[3];
			u_int8_t	sense_key;
		} __packed sync;
		struct {
			u_int32_t	l1;
			u_int32_t	l2;
			u_int32_t	l3;
			u_int32_t	l4;
		} __packed test;
	} eu;
	u_int32_t	severity;
	u_int8_t	event_string[256];
} __packed gdt_evt_data;

typedef struct {
	u_int32_t	first_stamp;
	u_int32_t	last_stamp;
	u_int16_t	same_count;
	u_int16_t	event_source;
	u_int16_t	event_idx;
	u_int8_t	application;
	u_int8_t	reserved;
	gdt_evt_data	event_data;
} __packed gdt_evt_str;

typedef struct gdt_event {
	int		erase;
	int		handle;
	gdt_evt_str	dvr;
} __packed gdt_event_t;
#define	GDT_IOCTL_EVENT		_IOWR('J', 7, gdt_event_t)

/* get statistics */
typedef struct gdt_statist {
	u_int16_t	io_count_act;
	u_int16_t	io_count_max;
	u_int16_t	req_queue_act;
	u_int16_t	req_queue_max;
	u_int16_t	cmd_index_act;
	u_int16_t	cmd_index_max;
	u_int16_t	sg_count_act;
	u_int16_t	sg_count_max;
} __packed gdt_statist_t;
#define	GDT_IOCTL_STATIST	_IOR('J', 9, gdt_statist_t)

/* rescan host drives */
typedef struct gdt_rescan {
	u_int16_t	io_node;
	u_int8_t	flag;
	u_int16_t	hdr_no;
	struct {
		u_int8_t	bus;
		u_int8_t	target;
		u_int8_t	lun;
		u_int8_t	cluster_type;
	} __packed hdr_list[ICP_MAX_HDRIVES];
} __packed gdt_rescan_t;
#define	GDT_IOCTL_RESCAN	_IOWR('J', 11, gdt_rescan_t)

#endif /* _DEV_IC_ICP_IOCTL_H_ */