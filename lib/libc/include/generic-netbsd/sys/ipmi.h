/*	$NetBSD: ipmi.h,v 1.1 2019/05/18 08:38:00 mlelstv Exp $	*/

/*-
 * Copyright (c) 2019 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Michael van Elst
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_IPMI_H_
#define	_SYS_IPMI_H_

#define	IPMI_MAX_ADDR_SIZE		0x20
#define IPMI_MAX_RX			1024
#define	IPMI_BMC_SLAVE_ADDR		0x20
#define	IPMI_BMC_CHANNEL		0x0f
#define	IPMI_BMC_SMS_LUN		0x02

#define IPMI_SYSTEM_INTERFACE_ADDR_TYPE	0x0c
#define IPMI_IPMB_ADDR_TYPE		0x01
#define IPMI_IPMB_BROADCAST_ADDR_TYPE	0x41

struct ipmi_msg {
	unsigned char	netfn;
	unsigned char	cmd;
	unsigned short	data_len;
	unsigned char	*data;
};

struct ipmi_req {
	unsigned char	*addr;
	unsigned int	addr_len;
	long		msgid;
	struct ipmi_msg msg;
};

struct ipmi_recv {
	int		recv_type;
#define IPMI_RESPONSE_RECV_TYPE		1
#define IPMI_ASYNC_EVENT_RECV_TYPE	2
#define IPMI_CMD_RECV_TYPE		3
	unsigned char	*addr;
	unsigned int	addr_len;
	long		msgid;
	struct ipmi_msg msg;
};

struct ipmi_cmdspec {
	unsigned char	netfn;
	unsigned char	cmd;
};

struct ipmi_addr {
	int		addr_type;
	short		channel;
	unsigned char	data[IPMI_MAX_ADDR_SIZE];
};

struct ipmi_system_interface_addr {
	int		addr_type;
	short		channel;
	unsigned char	lun;
};

struct ipmi_ipmb_addr {
	int		addr_type;
	short		channel;
	unsigned char	slave_addr;
	unsigned char	lun;
};

#define IPMICTL_RECEIVE_MSG_TRUNC       _IOWR('i', 11, struct ipmi_recv)
#define IPMICTL_RECEIVE_MSG             _IOWR('i', 12, struct ipmi_recv)
#define IPMICTL_SEND_COMMAND            _IOW('i', 13, struct ipmi_req)
#define IPMICTL_REGISTER_FOR_CMD        _IOW('i', 14, struct ipmi_cmdspec)
#define IPMICTL_UNREGISTER_FOR_CMD      _IOW('i', 15, struct ipmi_cmdspec)
#define IPMICTL_SET_GETS_EVENTS_CMD     _IOW('i', 16, int)
#define IPMICTL_SET_MY_ADDRESS_CMD      _IOW('i', 17, unsigned int)
#define IPMICTL_GET_MY_ADDRESS_CMD      _IOR('i', 18, unsigned int)
#define IPMICTL_SET_MY_LUN_CMD          _IOW('i', 19, unsigned int) 
#define IPMICTL_GET_MY_LUN_CMD          _IOR('i', 20, unsigned int)

#endif /* !_SYS_IPMI_H_ */