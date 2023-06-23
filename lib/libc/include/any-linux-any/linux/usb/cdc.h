/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/*
 * USB Communications Device Class (CDC) definitions
 *
 * CDC says how to talk to lots of different types of network adapters,
 * notably ethernet adapters and various modems.  It's used mostly with
 * firmware based USB peripherals.
 */

#ifndef __UAPI_LINUX_USB_CDC_H
#define __UAPI_LINUX_USB_CDC_H

#include <linux/types.h>

#define USB_CDC_SUBCLASS_ACM			0x02
#define USB_CDC_SUBCLASS_ETHERNET		0x06
#define USB_CDC_SUBCLASS_WHCM			0x08
#define USB_CDC_SUBCLASS_DMM			0x09
#define USB_CDC_SUBCLASS_MDLM			0x0a
#define USB_CDC_SUBCLASS_OBEX			0x0b
#define USB_CDC_SUBCLASS_EEM			0x0c
#define USB_CDC_SUBCLASS_NCM			0x0d
#define USB_CDC_SUBCLASS_MBIM			0x0e

#define USB_CDC_PROTO_NONE			0

#define USB_CDC_ACM_PROTO_AT_V25TER		1
#define USB_CDC_ACM_PROTO_AT_PCCA101		2
#define USB_CDC_ACM_PROTO_AT_PCCA101_WAKE	3
#define USB_CDC_ACM_PROTO_AT_GSM		4
#define USB_CDC_ACM_PROTO_AT_3G			5
#define USB_CDC_ACM_PROTO_AT_CDMA		6
#define USB_CDC_ACM_PROTO_VENDOR		0xff

#define USB_CDC_PROTO_EEM			7

#define USB_CDC_NCM_PROTO_NTB			1
#define USB_CDC_MBIM_PROTO_NTB			2

/*-------------------------------------------------------------------------*/

/*
 * Class-Specific descriptors ... there are a couple dozen of them
 */

#define USB_CDC_HEADER_TYPE		0x00	/* header_desc */
#define USB_CDC_CALL_MANAGEMENT_TYPE	0x01	/* call_mgmt_descriptor */
#define USB_CDC_ACM_TYPE		0x02	/* acm_descriptor */
#define USB_CDC_UNION_TYPE		0x06	/* union_desc */
#define USB_CDC_COUNTRY_TYPE		0x07
#define USB_CDC_NETWORK_TERMINAL_TYPE	0x0a	/* network_terminal_desc */
#define USB_CDC_ETHERNET_TYPE		0x0f	/* ether_desc */
#define USB_CDC_WHCM_TYPE		0x11
#define USB_CDC_MDLM_TYPE		0x12	/* mdlm_desc */
#define USB_CDC_MDLM_DETAIL_TYPE	0x13	/* mdlm_detail_desc */
#define USB_CDC_DMM_TYPE		0x14
#define USB_CDC_OBEX_TYPE		0x15
#define USB_CDC_NCM_TYPE		0x1a
#define USB_CDC_MBIM_TYPE		0x1b
#define USB_CDC_MBIM_EXTENDED_TYPE	0x1c

/* "Header Functional Descriptor" from CDC spec  5.2.3.1 */
struct usb_cdc_header_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__le16	bcdCDC;
} __attribute__ ((packed));

/* "Call Management Descriptor" from CDC spec  5.2.3.2 */
struct usb_cdc_call_mgmt_descriptor {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__u8	bmCapabilities;
#define USB_CDC_CALL_MGMT_CAP_CALL_MGMT		0x01
#define USB_CDC_CALL_MGMT_CAP_DATA_INTF		0x02

	__u8	bDataInterface;
} __attribute__ ((packed));

/* "Abstract Control Management Descriptor" from CDC spec  5.2.3.3 */
struct usb_cdc_acm_descriptor {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__u8	bmCapabilities;
} __attribute__ ((packed));

/* capabilities from 5.2.3.3 */

#define USB_CDC_COMM_FEATURE	0x01
#define USB_CDC_CAP_LINE	0x02
#define USB_CDC_CAP_BRK		0x04
#define USB_CDC_CAP_NOTIFY	0x08

/* "Union Functional Descriptor" from CDC spec 5.2.3.8 */
struct usb_cdc_union_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__u8	bMasterInterface0;
	__u8	bSlaveInterface0;
	/* ... and there could be other slave interfaces */
} __attribute__ ((packed));

/* "Country Selection Functional Descriptor" from CDC spec 5.2.3.9 */
struct usb_cdc_country_functional_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__u8	iCountryCodeRelDate;
	__le16	wCountyCode0;
	/* ... and there can be a lot of country codes */
} __attribute__ ((packed));

/* "Network Channel Terminal Functional Descriptor" from CDC spec 5.2.3.11 */
struct usb_cdc_network_terminal_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__u8	bEntityId;
	__u8	iName;
	__u8	bChannelIndex;
	__u8	bPhysicalInterface;
} __attribute__ ((packed));

/* "Ethernet Networking Functional Descriptor" from CDC spec 5.2.3.16 */
struct usb_cdc_ether_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__u8	iMACAddress;
	__le32	bmEthernetStatistics;
	__le16	wMaxSegmentSize;
	__le16	wNumberMCFilters;
	__u8	bNumberPowerFilters;
} __attribute__ ((packed));

/* "Telephone Control Model Functional Descriptor" from CDC WMC spec 6.3..3 */
struct usb_cdc_dmm_desc {
	__u8	bFunctionLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubtype;
	__u16	bcdVersion;
	__le16	wMaxCommand;
} __attribute__ ((packed));

/* "MDLM Functional Descriptor" from CDC WMC spec 6.7.2.3 */
struct usb_cdc_mdlm_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__le16	bcdVersion;
	__u8	bGUID[16];
} __attribute__ ((packed));

/* "MDLM Detail Functional Descriptor" from CDC WMC spec 6.7.2.4 */
struct usb_cdc_mdlm_detail_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	/* type is associated with mdlm_desc.bGUID */
	__u8	bGuidDescriptorType;
	__u8	bDetailData[];
} __attribute__ ((packed));

/* "OBEX Control Model Functional Descriptor" */
struct usb_cdc_obex_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__le16	bcdVersion;
} __attribute__ ((packed));

/* "NCM Control Model Functional Descriptor" */
struct usb_cdc_ncm_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__le16	bcdNcmVersion;
	__u8	bmNetworkCapabilities;
} __attribute__ ((packed));

/* "MBIM Control Model Functional Descriptor" */
struct usb_cdc_mbim_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__le16	bcdMBIMVersion;
	__le16  wMaxControlMessage;
	__u8    bNumberFilters;
	__u8    bMaxFilterSize;
	__le16  wMaxSegmentSize;
	__u8    bmNetworkCapabilities;
} __attribute__ ((packed));

/* "MBIM Extended Functional Descriptor" from CDC MBIM spec 1.0 errata-1 */
struct usb_cdc_mbim_extended_desc {
	__u8	bLength;
	__u8	bDescriptorType;
	__u8	bDescriptorSubType;

	__le16	bcdMBIMExtendedVersion;
	__u8	bMaxOutstandingCommandMessages;
	__le16	wMTU;
} __attribute__ ((packed));

/*-------------------------------------------------------------------------*/

/*
 * Class-Specific Control Requests (6.2)
 *
 * section 3.6.2.1 table 4 has the ACM profile, for modems.
 * section 3.8.2 table 10 has the ethernet profile.
 *
 * Microsoft's RNDIS stack for Ethernet is a vendor-specific CDC ACM variant,
 * heavily dependent on the encapsulated (proprietary) command mechanism.
 */

#define USB_CDC_SEND_ENCAPSULATED_COMMAND	0x00
#define USB_CDC_GET_ENCAPSULATED_RESPONSE	0x01
#define USB_CDC_REQ_SET_LINE_CODING		0x20
#define USB_CDC_REQ_GET_LINE_CODING		0x21
#define USB_CDC_REQ_SET_CONTROL_LINE_STATE	0x22
#define USB_CDC_REQ_SEND_BREAK			0x23
#define USB_CDC_SET_ETHERNET_MULTICAST_FILTERS	0x40
#define USB_CDC_SET_ETHERNET_PM_PATTERN_FILTER	0x41
#define USB_CDC_GET_ETHERNET_PM_PATTERN_FILTER	0x42
#define USB_CDC_SET_ETHERNET_PACKET_FILTER	0x43
#define USB_CDC_GET_ETHERNET_STATISTIC		0x44
#define USB_CDC_GET_NTB_PARAMETERS		0x80
#define USB_CDC_GET_NET_ADDRESS			0x81
#define USB_CDC_SET_NET_ADDRESS			0x82
#define USB_CDC_GET_NTB_FORMAT			0x83
#define USB_CDC_SET_NTB_FORMAT			0x84
#define USB_CDC_GET_NTB_INPUT_SIZE		0x85
#define USB_CDC_SET_NTB_INPUT_SIZE		0x86
#define USB_CDC_GET_MAX_DATAGRAM_SIZE		0x87
#define USB_CDC_SET_MAX_DATAGRAM_SIZE		0x88
#define USB_CDC_GET_CRC_MODE			0x89
#define USB_CDC_SET_CRC_MODE			0x8a

/* Line Coding Structure from CDC spec 6.2.13 */
struct usb_cdc_line_coding {
	__le32	dwDTERate;
	__u8	bCharFormat;
#define USB_CDC_1_STOP_BITS			0
#define USB_CDC_1_5_STOP_BITS			1
#define USB_CDC_2_STOP_BITS			2

	__u8	bParityType;
#define USB_CDC_NO_PARITY			0
#define USB_CDC_ODD_PARITY			1
#define USB_CDC_EVEN_PARITY			2
#define USB_CDC_MARK_PARITY			3
#define USB_CDC_SPACE_PARITY			4

	__u8	bDataBits;
} __attribute__ ((packed));

/* Control Signal Bitmap Values from 6.2.14 SetControlLineState */
#define USB_CDC_CTRL_DTR			(1 << 0)
#define USB_CDC_CTRL_RTS			(1 << 1)

/* table 62; bits in multicast filter */
#define	USB_CDC_PACKET_TYPE_PROMISCUOUS		(1 << 0)
#define	USB_CDC_PACKET_TYPE_ALL_MULTICAST	(1 << 1) /* no filter */
#define	USB_CDC_PACKET_TYPE_DIRECTED		(1 << 2)
#define	USB_CDC_PACKET_TYPE_BROADCAST		(1 << 3)
#define	USB_CDC_PACKET_TYPE_MULTICAST		(1 << 4) /* filtered */


/*-------------------------------------------------------------------------*/

/*
 * Class-Specific Notifications (6.3) sent by interrupt transfers
 *
 * section 3.8.2 table 11 of the CDC spec lists Ethernet notifications
 * section 3.6.2.1 table 5 specifies ACM notifications, accepted by RNDIS
 * RNDIS also defines its own bit-incompatible notifications
 */

#define USB_CDC_NOTIFY_NETWORK_CONNECTION	0x00
#define USB_CDC_NOTIFY_RESPONSE_AVAILABLE	0x01
#define USB_CDC_NOTIFY_SERIAL_STATE		0x20
#define USB_CDC_NOTIFY_SPEED_CHANGE		0x2a

struct usb_cdc_notification {
	__u8	bmRequestType;
	__u8	bNotificationType;
	__le16	wValue;
	__le16	wIndex;
	__le16	wLength;
} __attribute__ ((packed));

/* UART State Bitmap Values from 6.3.5 SerialState */
#define USB_CDC_SERIAL_STATE_DCD		(1 << 0)
#define USB_CDC_SERIAL_STATE_DSR		(1 << 1)
#define USB_CDC_SERIAL_STATE_BREAK		(1 << 2)
#define USB_CDC_SERIAL_STATE_RING_SIGNAL	(1 << 3)
#define USB_CDC_SERIAL_STATE_FRAMING		(1 << 4)
#define USB_CDC_SERIAL_STATE_PARITY		(1 << 5)
#define USB_CDC_SERIAL_STATE_OVERRUN		(1 << 6)

struct usb_cdc_speed_change {
	__le32	DLBitRRate;	/* contains the downlink bit rate (IN pipe) */
	__le32	ULBitRate;	/* contains the uplink bit rate (OUT pipe) */
} __attribute__ ((packed));

/*-------------------------------------------------------------------------*/

/*
 * Class Specific structures and constants
 *
 * CDC NCM NTB parameters structure, CDC NCM subclass 6.2.1
 *
 */

struct usb_cdc_ncm_ntb_parameters {
	__le16	wLength;
	__le16	bmNtbFormatsSupported;
	__le32	dwNtbInMaxSize;
	__le16	wNdpInDivisor;
	__le16	wNdpInPayloadRemainder;
	__le16	wNdpInAlignment;
	__le16	wPadding1;
	__le32	dwNtbOutMaxSize;
	__le16	wNdpOutDivisor;
	__le16	wNdpOutPayloadRemainder;
	__le16	wNdpOutAlignment;
	__le16	wNtbOutMaxDatagrams;
} __attribute__ ((packed));

/*
 * CDC NCM transfer headers, CDC NCM subclass 3.2
 */

#define USB_CDC_NCM_NTH16_SIGN		0x484D434E /* NCMH */
#define USB_CDC_NCM_NTH32_SIGN		0x686D636E /* ncmh */

struct usb_cdc_ncm_nth16 {
	__le32	dwSignature;
	__le16	wHeaderLength;
	__le16	wSequence;
	__le16	wBlockLength;
	__le16	wNdpIndex;
} __attribute__ ((packed));

struct usb_cdc_ncm_nth32 {
	__le32	dwSignature;
	__le16	wHeaderLength;
	__le16	wSequence;
	__le32	dwBlockLength;
	__le32	dwNdpIndex;
} __attribute__ ((packed));

/*
 * CDC NCM datagram pointers, CDC NCM subclass 3.3
 */

#define USB_CDC_NCM_NDP16_CRC_SIGN	0x314D434E /* NCM1 */
#define USB_CDC_NCM_NDP16_NOCRC_SIGN	0x304D434E /* NCM0 */
#define USB_CDC_NCM_NDP32_CRC_SIGN	0x316D636E /* ncm1 */
#define USB_CDC_NCM_NDP32_NOCRC_SIGN	0x306D636E /* ncm0 */

#define USB_CDC_MBIM_NDP16_IPS_SIGN     0x00535049 /* IPS<sessionID> : IPS0 for now */
#define USB_CDC_MBIM_NDP32_IPS_SIGN     0x00737069 /* ips<sessionID> : ips0 for now */
#define USB_CDC_MBIM_NDP16_DSS_SIGN     0x00535344 /* DSS<sessionID> */
#define USB_CDC_MBIM_NDP32_DSS_SIGN     0x00737364 /* dss<sessionID> */

/* 16-bit NCM Datagram Pointer Entry */
struct usb_cdc_ncm_dpe16 {
	__le16	wDatagramIndex;
	__le16	wDatagramLength;
} __attribute__((__packed__));

/* 16-bit NCM Datagram Pointer Table */
struct usb_cdc_ncm_ndp16 {
	__le32	dwSignature;
	__le16	wLength;
	__le16	wNextNdpIndex;
	struct	usb_cdc_ncm_dpe16 dpe16[];
} __attribute__ ((packed));

/* 32-bit NCM Datagram Pointer Entry */
struct usb_cdc_ncm_dpe32 {
	__le32	dwDatagramIndex;
	__le32	dwDatagramLength;
} __attribute__((__packed__));

/* 32-bit NCM Datagram Pointer Table */
struct usb_cdc_ncm_ndp32 {
	__le32	dwSignature;
	__le16	wLength;
	__le16	wReserved6;
	__le32	dwNextNdpIndex;
	__le32	dwReserved12;
	struct	usb_cdc_ncm_dpe32 dpe32[];
} __attribute__ ((packed));

/* CDC NCM subclass 3.2.1 and 3.2.2 */
#define USB_CDC_NCM_NDP16_INDEX_MIN			0x000C
#define USB_CDC_NCM_NDP32_INDEX_MIN			0x0010

/* CDC NCM subclass 3.3.3 Datagram Formatting */
#define USB_CDC_NCM_DATAGRAM_FORMAT_CRC			0x30
#define USB_CDC_NCM_DATAGRAM_FORMAT_NOCRC		0X31

/* CDC NCM subclass 4.2 NCM Communications Interface Protocol Code */
#define USB_CDC_NCM_PROTO_CODE_NO_ENCAP_COMMANDS	0x00
#define USB_CDC_NCM_PROTO_CODE_EXTERN_PROTO		0xFE

/* CDC NCM subclass 5.2.1 NCM Functional Descriptor, bmNetworkCapabilities */
#define USB_CDC_NCM_NCAP_ETH_FILTER			(1 << 0)
#define USB_CDC_NCM_NCAP_NET_ADDRESS			(1 << 1)
#define USB_CDC_NCM_NCAP_ENCAP_COMMAND			(1 << 2)
#define USB_CDC_NCM_NCAP_MAX_DATAGRAM_SIZE		(1 << 3)
#define USB_CDC_NCM_NCAP_CRC_MODE			(1 << 4)
#define	USB_CDC_NCM_NCAP_NTB_INPUT_SIZE			(1 << 5)

/* CDC NCM subclass Table 6-3: NTB Parameter Structure */
#define USB_CDC_NCM_NTB16_SUPPORTED			(1 << 0)
#define USB_CDC_NCM_NTB32_SUPPORTED			(1 << 1)

/* CDC NCM subclass Table 6-3: NTB Parameter Structure */
#define USB_CDC_NCM_NDP_ALIGN_MIN_SIZE			0x04
#define USB_CDC_NCM_NTB_MAX_LENGTH			0x1C

/* CDC NCM subclass 6.2.5 SetNtbFormat */
#define USB_CDC_NCM_NTB16_FORMAT			0x00
#define USB_CDC_NCM_NTB32_FORMAT			0x01

/* CDC NCM subclass 6.2.7 SetNtbInputSize */
#define USB_CDC_NCM_NTB_MIN_IN_SIZE			2048
#define USB_CDC_NCM_NTB_MIN_OUT_SIZE			2048

/* NTB Input Size Structure */
struct usb_cdc_ncm_ndp_input_size {
	__le32	dwNtbInMaxSize;
	__le16	wNtbInMaxDatagrams;
	__le16	wReserved;
} __attribute__ ((packed));

/* CDC NCM subclass 6.2.11 SetCrcMode */
#define USB_CDC_NCM_CRC_NOT_APPENDED			0x00
#define USB_CDC_NCM_CRC_APPENDED			0x01

#endif /* __UAPI_LINUX_USB_CDC_H */