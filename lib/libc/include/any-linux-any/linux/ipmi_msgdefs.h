/* SPDX-License-Identifier: GPL-2.0+ WITH Linux-syscall-note */
/*
 * ipmi_smi.h
 *
 * MontaVista IPMI system management interface
 *
 * Author: MontaVista Software, Inc.
 *         Corey Minyard <minyard@mvista.com>
 *         source@mvista.com
 *
 * Copyright 2002 MontaVista Software Inc.
 *
 */

#ifndef __LINUX_IPMI_MSGDEFS_H
#define __LINUX_IPMI_MSGDEFS_H

/* Various definitions for IPMI messages used by almost everything in
   the IPMI stack. */

/* NetFNs and commands used inside the IPMI stack. */

#define IPMI_NETFN_SENSOR_EVENT_REQUEST		0x04
#define IPMI_NETFN_SENSOR_EVENT_RESPONSE	0x05
#define IPMI_GET_EVENT_RECEIVER_CMD	0x01

#define IPMI_NETFN_APP_REQUEST			0x06
#define IPMI_NETFN_APP_RESPONSE			0x07
#define IPMI_GET_DEVICE_ID_CMD		0x01
#define IPMI_COLD_RESET_CMD		0x02
#define IPMI_WARM_RESET_CMD		0x03
#define IPMI_CLEAR_MSG_FLAGS_CMD	0x30
#define IPMI_GET_DEVICE_GUID_CMD	0x08
#define IPMI_GET_MSG_FLAGS_CMD		0x31
#define IPMI_SEND_MSG_CMD		0x34
#define IPMI_GET_MSG_CMD		0x33
#define IPMI_SET_BMC_GLOBAL_ENABLES_CMD	0x2e
#define IPMI_GET_BMC_GLOBAL_ENABLES_CMD	0x2f
#define IPMI_READ_EVENT_MSG_BUFFER_CMD	0x35
#define IPMI_GET_CHANNEL_INFO_CMD	0x42

/* Bit for BMC global enables. */
#define IPMI_BMC_RCV_MSG_INTR     0x01
#define IPMI_BMC_EVT_MSG_INTR     0x02
#define IPMI_BMC_EVT_MSG_BUFF     0x04
#define IPMI_BMC_SYS_LOG          0x08

#define IPMI_NETFN_STORAGE_REQUEST		0x0a
#define IPMI_NETFN_STORAGE_RESPONSE		0x0b
#define IPMI_ADD_SEL_ENTRY_CMD		0x44

#define IPMI_NETFN_FIRMWARE_REQUEST		0x08
#define IPMI_NETFN_FIRMWARE_RESPONSE		0x09

/* The default slave address */
#define IPMI_BMC_SLAVE_ADDR	0x20

/* The BT interface on high-end HP systems supports up to 255 bytes in
 * one transfer.  Its "virtual" BMC supports some commands that are longer
 * than 128 bytes.  Use the full 256, plus NetFn/LUN, Cmd, cCode, plus
 * some overhead; it's not worth the effort to dynamically size this based
 * on the results of the "Get BT Capabilities" command. */
#define IPMI_MAX_MSG_LENGTH	272	/* multiple of 16 */

#define IPMI_CC_NO_ERROR		0x00
#define IPMI_NODE_BUSY_ERR		0xc0
#define IPMI_INVALID_COMMAND_ERR	0xc1
#define IPMI_TIMEOUT_ERR		0xc3
#define IPMI_ERR_MSG_TRUNCATED		0xc6
#define IPMI_REQ_LEN_INVALID_ERR	0xc7
#define IPMI_REQ_LEN_EXCEEDED_ERR	0xc8
#define IPMI_DEVICE_IN_FW_UPDATE_ERR	0xd1
#define IPMI_DEVICE_IN_INIT_ERR		0xd2
#define IPMI_NOT_IN_MY_STATE_ERR	0xd5	/* IPMI 2.0 */
#define IPMI_LOST_ARBITRATION_ERR	0x81
#define IPMI_BUS_ERR			0x82
#define IPMI_NAK_ON_WRITE_ERR		0x83
#define IPMI_ERR_UNSPECIFIED		0xff

#define IPMI_CHANNEL_PROTOCOL_IPMB	1
#define IPMI_CHANNEL_PROTOCOL_ICMB	2
#define IPMI_CHANNEL_PROTOCOL_SMBUS	4
#define IPMI_CHANNEL_PROTOCOL_KCS	5
#define IPMI_CHANNEL_PROTOCOL_SMIC	6
#define IPMI_CHANNEL_PROTOCOL_BT10	7
#define IPMI_CHANNEL_PROTOCOL_BT15	8
#define IPMI_CHANNEL_PROTOCOL_TMODE	9

#define IPMI_CHANNEL_MEDIUM_IPMB	1
#define IPMI_CHANNEL_MEDIUM_ICMB10	2
#define IPMI_CHANNEL_MEDIUM_ICMB09	3
#define IPMI_CHANNEL_MEDIUM_8023LAN	4
#define IPMI_CHANNEL_MEDIUM_ASYNC	5
#define IPMI_CHANNEL_MEDIUM_OTHER_LAN	6
#define IPMI_CHANNEL_MEDIUM_PCI_SMBUS	7
#define IPMI_CHANNEL_MEDIUM_SMBUS1	8
#define IPMI_CHANNEL_MEDIUM_SMBUS2	9
#define IPMI_CHANNEL_MEDIUM_USB1	10
#define IPMI_CHANNEL_MEDIUM_USB2	11
#define IPMI_CHANNEL_MEDIUM_SYSINTF	12
#define IPMI_CHANNEL_MEDIUM_OEM_MIN	0x60
#define IPMI_CHANNEL_MEDIUM_OEM_MAX	0x7f

#endif /* __LINUX_IPMI_MSGDEFS_H */