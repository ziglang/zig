/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2022-2024 Chelsio Communications, Inc.
 * Written by: John Baldwin <jhb@FreeBSD.org>
 */

#ifndef __NVMF_H__
#define	__NVMF_H__

#include <sys/ioccom.h>
#ifndef _KERNEL
#include <stdbool.h>
#endif

/*
 * Default settings in Fabrics controllers.  These match values used by the
 * Linux target.
 */
#define	NVMF_MAX_IO_ENTRIES	(1024)
#define	NVMF_CC_EN_TIMEOUT	(15)	/* In 500ms units */

/* Allows for a 16k data buffer + SQE */
#define	NVMF_IOCCSZ		(sizeof(struct nvme_command) + 16 * 1024)
#define	NVMF_IORCSZ		(sizeof(struct nvme_completion))

#define	NVMF_NN			(1024)

/*
 * Default timeouts for Fabrics hosts.  These match values used by
 * Linux.
 */
#define	NVMF_DEFAULT_RECONNECT_DELAY	10
#define	NVMF_DEFAULT_CONTROLLER_LOSS	600

/*
 * (data, size) is the userspace buffer for a packed nvlist.
 *
 * For requests that copyout an nvlist, len is the amount of data
 * copied out to *data.  If size is zero, no data is copied and len is
 * set to the required buffer size.
 */
struct nvmf_ioc_nv {
	void	*data;
	size_t	len;
	size_t	size;
};

/*
 * The fields in a qpair handoff nvlist are:
 *
 * Transport independent:
 *
 * bool		admin
 * bool		sq_flow_control
 * number	qsize
 * number	sqhd
 * number	sqtail			host only
 *
 * TCP transport:
 *
 * number	fd
 * number	rxpda
 * number	txpda
 * bool		header_digests
 * bool		data_digests
 * number	maxr2t
 * number	maxh2cdata
 * number	max_icd
 */

/*
 * The fields in the nvlist for NVMF_HANDOFF_HOST and
 * NVMF_RECONNECT_HOST are:
 *
 * number			trtype
 * number			kato	(optional)
 * number                       reconnect_delay (optional)
 * number                       controller_loss_timeout (optional)
 * qpair handoff nvlist		admin
 * qpair handoff nvlist array	io
 * binary			cdata	struct nvme_controller_data
 * NVMF_RECONNECT_PARAMS nvlist	rparams
 */

/*
 * The fields in the nvlist for NVMF_RECONNECT_PARAMS are:
 *
 * binary			dle	struct nvme_discovery_log_entry
 * string			hostnqn
 * number			num_io_queues
 * number			kato	(optional)
 * number                       reconnect_delay (optional)
 * number                       controller_loss_timeout (optional)
 * number			io_qsize
 * bool				sq_flow_control
 *
 * TCP transport:
 *
 * bool				header_digests
 * bool				data_digests
 */

/*
 * The fields in the nvlist for NVMF_CONNECTION_STATUS are:
 *
 * bool				connected
 * timespec nvlist		last_disconnect
 *  number			tv_sec
 *  number			tv_nsec
 */

/*
 * The fields in the nvlist for handing off a controller qpair are:
 *
 * number			trtype
 * qpair handoff nvlist		params
 * binary			cmd	struct nvmf_fabric_connect_cmd
 * binary			data	struct nvmf_fabric_connect_data
 */

/* Operations on /dev/nvmf */
#define	NVMF_HANDOFF_HOST	_IOW('n', 200, struct nvmf_ioc_nv)
#define	NVMF_DISCONNECT_HOST	_IOW('n', 201, const char *)
#define	NVMF_DISCONNECT_ALL	_IO('n', 202)

/* Operations on /dev/nvmeX */
#define	NVMF_RECONNECT_PARAMS	_IOWR('n', 203, struct nvmf_ioc_nv)
#define	NVMF_RECONNECT_HOST	_IOW('n', 204, struct nvmf_ioc_nv)
#define	NVMF_CONNECTION_STATUS	_IOWR('n', 205, struct nvmf_ioc_nv)

#endif /* !__NVMF_H__ */