/* SPDX-License-Identifier: ((GPL-2.0 WITH Linux-syscall-note) OR Linux-OpenIB) */
/*
 * Copyright (c) 2016 Mellanox Technologies, LTD. All rights reserved.
 *
 * This software is available to you under a choice of one of two
 * licenses.  You may choose to be licensed under the terms of the GNU
 * General Public License (GPL) Version 2, available from the file
 * COPYING in the main directory of this source tree, or the
 * OpenIB.org BSD license below:
 *
 *     Redistribution and use in source and binary forms, with or
 *     without modification, are permitted provided that the following
 *     conditions are met:
 *
 *      - Redistributions of source code must retain the above
 *        copyright notice, this list of conditions and the following
 *        disclaimer.
 *
 *      - Redistributions in binary form must reproduce the above
 *        copyright notice, this list of conditions and the following
 *        disclaimer in the documentation and/or other materials
 *        provided with the distribution.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef RDMA_USER_IOCTL_H
#define RDMA_USER_IOCTL_H

#include <rdma/ib_user_mad.h>
#include <rdma/hfi/hfi1_ioctl.h>
#include <rdma/rdma_user_ioctl_cmds.h>

/* Legacy name, for user space application which already use it */
#define IB_IOCTL_MAGIC		RDMA_IOCTL_MAGIC

/*
 * General blocks assignments
 * It is closed on purpose - do not expose it to user space
 * #define MAD_CMD_BASE		0x00
 * #define HFI1_CMD_BAS		0xE0
 */

/* MAD specific section */
#define IB_USER_MAD_REGISTER_AGENT	_IOWR(RDMA_IOCTL_MAGIC, 0x01, struct ib_user_mad_reg_req)
#define IB_USER_MAD_UNREGISTER_AGENT	_IOW(RDMA_IOCTL_MAGIC,  0x02, __u32)
#define IB_USER_MAD_ENABLE_PKEY		_IO(RDMA_IOCTL_MAGIC,   0x03)
#define IB_USER_MAD_REGISTER_AGENT2	_IOWR(RDMA_IOCTL_MAGIC, 0x04, struct ib_user_mad_reg_req2)

/* HFI specific section */
/* allocate HFI and context */
#define HFI1_IOCTL_ASSIGN_CTXT		_IOWR(RDMA_IOCTL_MAGIC, 0xE1, struct hfi1_user_info)
/* find out what resources we got */
#define HFI1_IOCTL_CTXT_INFO		_IOW(RDMA_IOCTL_MAGIC,  0xE2, struct hfi1_ctxt_info)
/* set up userspace */
#define HFI1_IOCTL_USER_INFO		_IOW(RDMA_IOCTL_MAGIC,  0xE3, struct hfi1_base_info)
/* update expected TID entries */
#define HFI1_IOCTL_TID_UPDATE		_IOWR(RDMA_IOCTL_MAGIC, 0xE4, struct hfi1_tid_info)
/* free expected TID entries */
#define HFI1_IOCTL_TID_FREE		_IOWR(RDMA_IOCTL_MAGIC, 0xE5, struct hfi1_tid_info)
/* force an update of PIO credit */
#define HFI1_IOCTL_CREDIT_UPD		_IO(RDMA_IOCTL_MAGIC,   0xE6)
/* control receipt of packets */
#define HFI1_IOCTL_RECV_CTRL		_IOW(RDMA_IOCTL_MAGIC,  0xE8, int)
/* set the kind of polling we want */
#define HFI1_IOCTL_POLL_TYPE		_IOW(RDMA_IOCTL_MAGIC,  0xE9, int)
/* ack & clear user status bits */
#define HFI1_IOCTL_ACK_EVENT		_IOW(RDMA_IOCTL_MAGIC,  0xEA, unsigned long)
/* set context's pkey */
#define HFI1_IOCTL_SET_PKEY		_IOW(RDMA_IOCTL_MAGIC,  0xEB, __u16)
/* reset context's HW send context */
#define HFI1_IOCTL_CTXT_RESET		_IO(RDMA_IOCTL_MAGIC,   0xEC)
/* read TID cache invalidations */
#define HFI1_IOCTL_TID_INVAL_READ	_IOWR(RDMA_IOCTL_MAGIC, 0xED, struct hfi1_tid_info)
/* get the version of the user cdev */
#define HFI1_IOCTL_GET_VERS		_IOR(RDMA_IOCTL_MAGIC,  0xEE, int)

#endif /* RDMA_USER_IOCTL_H */