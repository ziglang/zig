/*
 * Copyright (C) 2011 Instituto Nokia de Tecnologia
 *
 * Authors:
 *    Lauro Ramos Venancio <lauro.venancio@openbossa.org>
 *    Aloisio Almeida Jr <aloisio.almeida@openbossa.org>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef __LINUX_NFC_H
#define __LINUX_NFC_H

#include <linux/types.h>
#include <linux/socket.h>

#define NFC_GENL_NAME "nfc"
#define NFC_GENL_VERSION 1

#define NFC_GENL_MCAST_EVENT_NAME "events"

/**
 * enum nfc_commands - supported nfc commands
 *
 * @NFC_CMD_UNSPEC: unspecified command
 *
 * @NFC_CMD_GET_DEVICE: request information about a device (requires
 *	%NFC_ATTR_DEVICE_INDEX) or dump request to get a list of all nfc devices
 * @NFC_CMD_DEV_UP: turn on the nfc device
 *	(requires %NFC_ATTR_DEVICE_INDEX)
 * @NFC_CMD_DEV_DOWN: turn off the nfc device
 *	(requires %NFC_ATTR_DEVICE_INDEX)
 * @NFC_CMD_START_POLL: start polling for targets using the given protocols
 *	(requires %NFC_ATTR_DEVICE_INDEX and %NFC_ATTR_PROTOCOLS)
 * @NFC_CMD_STOP_POLL: stop polling for targets (requires
 *	%NFC_ATTR_DEVICE_INDEX)
 * @NFC_CMD_GET_TARGET: dump all targets found by the previous poll (requires
 *	%NFC_ATTR_DEVICE_INDEX)
 * @NFC_EVENT_TARGETS_FOUND: event emitted when a new target is found
 *	(it sends %NFC_ATTR_DEVICE_INDEX)
 * @NFC_EVENT_DEVICE_ADDED: event emitted when a new device is registred
 *	(it sends %NFC_ATTR_DEVICE_NAME, %NFC_ATTR_DEVICE_INDEX and
 *	%NFC_ATTR_PROTOCOLS)
 * @NFC_EVENT_DEVICE_REMOVED: event emitted when a device is removed
 *	(it sends %NFC_ATTR_DEVICE_INDEX)
 * @NFC_EVENT_TM_ACTIVATED: event emitted when the adapter is activated in
 *      target mode.
 * @NFC_EVENT_DEVICE_DEACTIVATED: event emitted when the adapter is deactivated
 *      from target mode.
 * @NFC_CMD_LLC_GET_PARAMS: request LTO, RW, and MIUX parameters for a device
 * @NFC_CMD_LLC_SET_PARAMS: set one or more of LTO, RW, and MIUX parameters for
 *	a device. LTO must be set before the link is up otherwise -EINPROGRESS
 *	is returned. RW and MIUX can be set at anytime and will be passed in
 *	subsequent CONNECT and CC messages.
 *	If one of the passed parameters is wrong none is set and -EINVAL is
 *	returned.
 * @NFC_CMD_ENABLE_SE: Enable the physical link to a specific secure element.
 *	Once enabled a secure element will handle card emulation mode, i.e.
 *	starting a poll from a device which has a secure element enabled means
 *	we want to do SE based card emulation.
 * @NFC_CMD_DISABLE_SE: Disable the physical link to a specific secure element.
 * @NFC_CMD_FW_DOWNLOAD: Request to Load/flash firmware, or event to inform
 *	that some firmware was loaded
 * @NFC_EVENT_SE_ADDED: Event emitted when a new secure element is discovered.
 *	This typically will be sent whenever a new NFC controller with either
 *	an embedded SE or an UICC one connected to it through SWP.
 * @NFC_EVENT_SE_REMOVED: Event emitted when a secure element is removed from
 *	the system, as a consequence of e.g. an NFC controller being unplugged.
 * @NFC_EVENT_SE_CONNECTIVITY: This event is emitted whenever a secure element
 *	is requesting connectivity access. For example a UICC SE may need to
 *	talk with a sleeping modem and will notify this need by sending this
 *	event. It is then up to userspace to decide if it will wake the modem
 *	up or not.
 * @NFC_EVENT_SE_TRANSACTION: This event is sent when an application running on
 *	a specific SE notifies us about the end of a transaction. The parameter
 *	for this event is the application ID (AID).
 * @NFC_CMD_GET_SE: Dump all discovered secure elements from an NFC controller.
 * @NFC_CMD_SE_IO: Send/Receive APDUs to/from the selected secure element.
 * @NFC_CMD_ACTIVATE_TARGET: Request NFC controller to reactivate target.
 * @NFC_CMD_VENDOR: Vendor specific command, to be implemented directly
 *	from the driver in order to support hardware specific operations.
 * @NFC_CMD_DEACTIVATE_TARGET: Request NFC controller to deactivate target.
 */
enum nfc_commands {
	NFC_CMD_UNSPEC,
	NFC_CMD_GET_DEVICE,
	NFC_CMD_DEV_UP,
	NFC_CMD_DEV_DOWN,
	NFC_CMD_DEP_LINK_UP,
	NFC_CMD_DEP_LINK_DOWN,
	NFC_CMD_START_POLL,
	NFC_CMD_STOP_POLL,
	NFC_CMD_GET_TARGET,
	NFC_EVENT_TARGETS_FOUND,
	NFC_EVENT_DEVICE_ADDED,
	NFC_EVENT_DEVICE_REMOVED,
	NFC_EVENT_TARGET_LOST,
	NFC_EVENT_TM_ACTIVATED,
	NFC_EVENT_TM_DEACTIVATED,
	NFC_CMD_LLC_GET_PARAMS,
	NFC_CMD_LLC_SET_PARAMS,
	NFC_CMD_ENABLE_SE,
	NFC_CMD_DISABLE_SE,
	NFC_CMD_LLC_SDREQ,
	NFC_EVENT_LLC_SDRES,
	NFC_CMD_FW_DOWNLOAD,
	NFC_EVENT_SE_ADDED,
	NFC_EVENT_SE_REMOVED,
	NFC_EVENT_SE_CONNECTIVITY,
	NFC_EVENT_SE_TRANSACTION,
	NFC_CMD_GET_SE,
	NFC_CMD_SE_IO,
	NFC_CMD_ACTIVATE_TARGET,
	NFC_CMD_VENDOR,
	NFC_CMD_DEACTIVATE_TARGET,
/* private: internal use only */
	__NFC_CMD_AFTER_LAST
};
#define NFC_CMD_MAX (__NFC_CMD_AFTER_LAST - 1)

/**
 * enum nfc_attrs - supported nfc attributes
 *
 * @NFC_ATTR_UNSPEC: unspecified attribute
 *
 * @NFC_ATTR_DEVICE_INDEX: index of nfc device
 * @NFC_ATTR_DEVICE_NAME: device name, max 8 chars
 * @NFC_ATTR_PROTOCOLS: nfc protocols - bitwise or-ed combination from
 *	NFC_PROTO_*_MASK constants
 * @NFC_ATTR_TARGET_INDEX: index of the nfc target
 * @NFC_ATTR_TARGET_SENS_RES: NFC-A targets extra information such as NFCID
 * @NFC_ATTR_TARGET_SEL_RES: NFC-A targets extra information (useful if the
 *	target is not NFC-Forum compliant)
 * @NFC_ATTR_TARGET_NFCID1: NFC-A targets identifier, max 10 bytes
 * @NFC_ATTR_TARGET_SENSB_RES: NFC-B targets extra information, max 12 bytes
 * @NFC_ATTR_TARGET_SENSF_RES: NFC-F targets extra information, max 18 bytes
 * @NFC_ATTR_COMM_MODE: Passive or active mode
 * @NFC_ATTR_RF_MODE: Initiator or target
 * @NFC_ATTR_IM_PROTOCOLS: Initiator mode protocols to poll for
 * @NFC_ATTR_TM_PROTOCOLS: Target mode protocols to listen for
 * @NFC_ATTR_LLC_PARAM_LTO: Link TimeOut parameter
 * @NFC_ATTR_LLC_PARAM_RW: Receive Window size parameter
 * @NFC_ATTR_LLC_PARAM_MIUX: MIU eXtension parameter
 * @NFC_ATTR_SE: Available Secure Elements
 * @NFC_ATTR_FIRMWARE_NAME: Free format firmware version
 * @NFC_ATTR_SE_INDEX: Secure element index
 * @NFC_ATTR_SE_TYPE: Secure element type (UICC or EMBEDDED)
 * @NFC_ATTR_FIRMWARE_DOWNLOAD_STATUS: Firmware download operation status
 * @NFC_ATTR_APDU: Secure element APDU
 * @NFC_ATTR_TARGET_ISO15693_DSFID: ISO 15693 Data Storage Format Identifier
 * @NFC_ATTR_TARGET_ISO15693_UID: ISO 15693 Unique Identifier
 * @NFC_ATTR_SE_PARAMS: Parameters data from an evt_transaction
 * @NFC_ATTR_VENDOR_ID: NFC manufacturer unique ID, typically an OUI
 * @NFC_ATTR_VENDOR_SUBCMD: Vendor specific sub command
 * @NFC_ATTR_VENDOR_DATA: Vendor specific data, to be optionally passed
 *	to a vendor specific command implementation
 */
enum nfc_attrs {
	NFC_ATTR_UNSPEC,
	NFC_ATTR_DEVICE_INDEX,
	NFC_ATTR_DEVICE_NAME,
	NFC_ATTR_PROTOCOLS,
	NFC_ATTR_TARGET_INDEX,
	NFC_ATTR_TARGET_SENS_RES,
	NFC_ATTR_TARGET_SEL_RES,
	NFC_ATTR_TARGET_NFCID1,
	NFC_ATTR_TARGET_SENSB_RES,
	NFC_ATTR_TARGET_SENSF_RES,
	NFC_ATTR_COMM_MODE,
	NFC_ATTR_RF_MODE,
	NFC_ATTR_DEVICE_POWERED,
	NFC_ATTR_IM_PROTOCOLS,
	NFC_ATTR_TM_PROTOCOLS,
	NFC_ATTR_LLC_PARAM_LTO,
	NFC_ATTR_LLC_PARAM_RW,
	NFC_ATTR_LLC_PARAM_MIUX,
	NFC_ATTR_SE,
	NFC_ATTR_LLC_SDP,
	NFC_ATTR_FIRMWARE_NAME,
	NFC_ATTR_SE_INDEX,
	NFC_ATTR_SE_TYPE,
	NFC_ATTR_SE_AID,
	NFC_ATTR_FIRMWARE_DOWNLOAD_STATUS,
	NFC_ATTR_SE_APDU,
	NFC_ATTR_TARGET_ISO15693_DSFID,
	NFC_ATTR_TARGET_ISO15693_UID,
	NFC_ATTR_SE_PARAMS,
	NFC_ATTR_VENDOR_ID,
	NFC_ATTR_VENDOR_SUBCMD,
	NFC_ATTR_VENDOR_DATA,
/* private: internal use only */
	__NFC_ATTR_AFTER_LAST
};
#define NFC_ATTR_MAX (__NFC_ATTR_AFTER_LAST - 1)

enum nfc_sdp_attr {
	NFC_SDP_ATTR_UNSPEC,
	NFC_SDP_ATTR_URI,
	NFC_SDP_ATTR_SAP,
/* private: internal use only */
	__NFC_SDP_ATTR_AFTER_LAST
};
#define NFC_SDP_ATTR_MAX (__NFC_SDP_ATTR_AFTER_LAST - 1)

#define NFC_DEVICE_NAME_MAXSIZE		8
#define NFC_NFCID1_MAXSIZE		10
#define NFC_NFCID2_MAXSIZE		8
#define NFC_NFCID3_MAXSIZE		10
#define NFC_SENSB_RES_MAXSIZE		12
#define NFC_SENSF_RES_MAXSIZE		18
#define NFC_ATR_REQ_MAXSIZE		64
#define NFC_ATR_RES_MAXSIZE		64
#define NFC_ATR_REQ_GB_MAXSIZE		48
#define NFC_ATR_RES_GB_MAXSIZE		47
#define NFC_GB_MAXSIZE			48
#define NFC_FIRMWARE_NAME_MAXSIZE	32
#define NFC_ISO15693_UID_MAXSIZE	8

/* NFC protocols */
#define NFC_PROTO_JEWEL		1
#define NFC_PROTO_MIFARE	2
#define NFC_PROTO_FELICA	3
#define NFC_PROTO_ISO14443	4
#define NFC_PROTO_NFC_DEP	5
#define NFC_PROTO_ISO14443_B	6
#define NFC_PROTO_ISO15693	7

#define NFC_PROTO_MAX		8

/* NFC communication modes */
#define NFC_COMM_ACTIVE  0
#define NFC_COMM_PASSIVE 1

/* NFC RF modes */
#define NFC_RF_INITIATOR 0
#define NFC_RF_TARGET    1
#define NFC_RF_NONE      2

/* NFC protocols masks used in bitsets */
#define NFC_PROTO_JEWEL_MASK      (1 << NFC_PROTO_JEWEL)
#define NFC_PROTO_MIFARE_MASK     (1 << NFC_PROTO_MIFARE)
#define NFC_PROTO_FELICA_MASK	  (1 << NFC_PROTO_FELICA)
#define NFC_PROTO_ISO14443_MASK	  (1 << NFC_PROTO_ISO14443)
#define NFC_PROTO_NFC_DEP_MASK	  (1 << NFC_PROTO_NFC_DEP)
#define NFC_PROTO_ISO14443_B_MASK (1 << NFC_PROTO_ISO14443_B)
#define NFC_PROTO_ISO15693_MASK	  (1 << NFC_PROTO_ISO15693)

/* NFC Secure Elements */
#define NFC_SE_UICC     0x1
#define NFC_SE_EMBEDDED 0x2

#define NFC_SE_DISABLED 0x0
#define NFC_SE_ENABLED  0x1

struct sockaddr_nfc {
	__kernel_sa_family_t sa_family;
	__u32 dev_idx;
	__u32 target_idx;
	__u32 nfc_protocol;
};

#define NFC_LLCP_MAX_SERVICE_NAME 63
struct sockaddr_nfc_llcp {
	__kernel_sa_family_t sa_family;
	__u32 dev_idx;
	__u32 target_idx;
	__u32 nfc_protocol;
	__u8 dsap; /* Destination SAP, if known */
	__u8 ssap; /* Source SAP to be bound to */
	char service_name[NFC_LLCP_MAX_SERVICE_NAME]; /* Service name URI */;
	__kernel_size_t service_name_len;
};

/* NFC socket protocols */
#define NFC_SOCKPROTO_RAW	0
#define NFC_SOCKPROTO_LLCP	1
#define NFC_SOCKPROTO_MAX	2

#define NFC_HEADER_SIZE 1

/**
 * Pseudo-header info for raw socket packets
 * First byte is the adapter index
 * Second byte contains flags
 *  - 0x01 - Direction (0=RX, 1=TX)
 *  - 0x02-0x04 - Payload type (000=LLCP, 001=NCI, 010=HCI, 011=Digital,
 *                              100=Proprietary)
 *  - 0x05-0x80 - Reserved
 **/
#define NFC_RAW_HEADER_SIZE	2
#define NFC_DIRECTION_RX		0x00
#define NFC_DIRECTION_TX		0x01

#define RAW_PAYLOAD_LLCP 0
#define RAW_PAYLOAD_NCI	1
#define RAW_PAYLOAD_HCI	2
#define RAW_PAYLOAD_DIGITAL	3
#define RAW_PAYLOAD_PROPRIETARY	4

/* socket option names */
#define NFC_LLCP_RW		0
#define NFC_LLCP_MIUX		1
#define NFC_LLCP_REMOTE_MIU	2
#define NFC_LLCP_REMOTE_LTO	3
#define NFC_LLCP_REMOTE_RW	4

#endif /*__LINUX_NFC_H */