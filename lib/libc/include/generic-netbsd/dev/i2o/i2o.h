/*	$NetBSD: i2o.h,v 1.17 2022/05/30 09:56:04 andvar Exp $	*/

/*-
 * Copyright (c) 2000, 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Andrew Doran.
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

/*
 * Structures and constants, as presented by the I2O specification revision
 * 1.5 (obtainable from http://www.intelligent-io.com/).  Currently, only
 * what's useful to us is defined in this file.
 */

#ifndef	_I2O_I2O_H_
#define	_I2O_I2O_H_

#include <sys/cdefs.h>
#include <sys/types.h>

/*
 * ================= Miscellaneous definitions =================
 */

/* Organisation IDs */
#define	I2O_ORG_DPT			0x001b
#define	I2O_ORG_INTEL			0x0028
#define	I2O_ORG_AMI			0x1000

/* Macros to assist in building message headers */
#define	I2O_MSGFLAGS(s)		(I2O_VERSION_11 | (sizeof(struct s) << 14))
#define	I2O_MSGFUNC(t, f)	((t) | (I2O_TID_HOST << 12) | ((f) << 24))
#define	I2O_MSGPRIV(o, f)	((f) | ((o) << 16))

/* Common message function codes with no payload or an undefined payload */
#define	I2O_UTIL_NOP			0x00
#define	I2O_EXEC_IOP_CLEAR		0xbe
#define	I2O_EXEC_SYS_QUIESCE		0xc3
#define	I2O_EXEC_SYS_ENABLE		0xd1
#define	I2O_PRIVATE_MESSAGE		0xff

/* Device class codes */
#define	I2O_CLASS_EXECUTIVE			0x00
#define	I2O_CLASS_DDM				0x01
#define	I2O_CLASS_RANDOM_BLOCK_STORAGE		0x10
#define	I2O_CLASS_SEQUENTIAL_STORAGE		0x11
#define	I2O_CLASS_LAN				0x20
#define	I2O_CLASS_WAN				0x30
#define	I2O_CLASS_FIBRE_CHANNEL_PORT		0x40
#define	I2O_CLASS_FIBRE_CHANNEL_PERIPHERAL	0x41
#define	I2O_CLASS_SCSI_PERIPHERAL		0x51
#define	I2O_CLASS_ATE_PORT			0x60
#define	I2O_CLASS_ATE_PERIPHERAL		0x61
#define	I2O_CLASS_FLOPPY_CONTROLLER		0x70
#define	I2O_CLASS_FLOPPY_DEVICE			0x71
#define	I2O_CLASS_BUS_ADAPTER_PORT		0x80

#define	I2O_CLASS_ANY				0xffffffff

/* Reply status codes */
#define	I2O_STATUS_SUCCESS			0x00
#define	I2O_STATUS_ABORT_DIRTY			0x01
#define	I2O_STATUS_ABORT_NO_DATA_XFER		0x02
#define	I2O_STATUS_ABORT_PARTIAL_XFER		0x03
#define	I2O_STATUS_ERROR_DIRTY			0x04
#define	I2O_STATUS_ERROR_NO_DATA_XFER		0x05
#define	I2O_STATUS_ERROR_PARTIAL_XFER		0x06
#define	I2O_STATUS_PROCESS_ABORT_DIRTY        	0x08
#define	I2O_STATUS_PROCESS_ABORT_NO_DATA_XFER	0x09
#define	I2O_STATUS_PROCESS_ABORT_PARTIAL_XFER	0x0a
#define	I2O_STATUS_TRANSACTION_ERROR		0x0b
#define	I2O_STATUS_PROGRESS_REPORT		0x80

/* Detailed status codes */
#define	I2O_DSC_SUCCESS				0x00
#define	I2O_DSC_BAD_KEY				0x02
#define	I2O_DSC_TCL_ERROR			0x03
#define	I2O_DSC_REPLY_BUFFER_FULL		0x04
#define	I2O_DSC_NO_SUCH_PAGE			0x05
#define	I2O_DSC_INSUFFICIENT_RESOURCE_SOFT	0x06
#define	I2O_DSC_INSUFFICIENT_RESOURCE_HARD	0x07
#define	I2O_DSC_CHAIN_BUFFER_TOO_LARGE		0x09
#define	I2O_DSC_UNSUPPORTED_FUNCTION		0x0a
#define	I2O_DSC_DEVICE_LOCKED			0x0b
#define	I2O_DSC_DEVICE_RESET			0x0c
#define	I2O_DSC_INAPPROPRIATE_FUNCTION		0x0d
#define	I2O_DSC_INVALID_INITIATOR_ADDRESS	0x0e
#define	I2O_DSC_INVALID_MESSAGE_FLAGS		0x0f
#define	I2O_DSC_INVALID_OFFSET			0x10
#define	I2O_DSC_INVALID_PARAMETER		0x11
#define	I2O_DSC_INVALID_REQUEST			0x12
#define	I2O_DSC_INVALID_TARGET_ADDRESS		0x13
#define	I2O_DSC_MESSAGE_TOO_LARGE		0x14
#define	I2O_DSC_MESSAGE_TOO_SMALL		0x15
#define	I2O_DSC_MISSING_PARAMETER		0x16
#define	I2O_DSC_TIMEOUT				0x17
#define	I2O_DSC_UNKNOWN_ERROR			0x18
#define	I2O_DSC_UNKNOWN_FUNCTION		0x19
#define	I2O_DSC_UNSUPPORTED_VERSION		0x1a
#define	I2O_DSC_DEVICE_BUSY			0x1b
#define	I2O_DSC_DEVICE_NOT_AVAILABLE		0x1c

/* Message versions */
#define	I2O_VERSION_10			0x00
#define	I2O_VERSION_11			0x01
#define	I2O_VERSION_20			0x02

/* Commonly used TIDs */
#define	I2O_TID_IOP			0
#define	I2O_TID_HOST			1
#define	I2O_TID_NONE			4095

/* SGL flags.  This list covers only a fraction of the possibilities. */
#define	I2O_SGL_IGNORE			0x00000000
#define	I2O_SGL_SIMPLE			0x10000000
#define	I2O_SGL_PAGE_LIST		0x20000000

#define	I2O_SGL_BC_32BIT		0x01000000
#define	I2O_SGL_BC_64BIT		0x02000000
#define	I2O_SGL_BC_96BIT		0x03000000
#define	I2O_SGL_DATA_OUT		0x04000000
#define	I2O_SGL_END_BUFFER		0x40000000
#define	I2O_SGL_END			0x80000000

/* Serial number formats */
#define	I2O_SNFMT_UNKNOWN		0
#define	I2O_SNFMT_BINARY		1
#define	I2O_SNFMT_ASCII			2
#define	I2O_SNFMT_UNICODE		3
#define	I2O_SNFMT_LAN_MAC		4
#define	I2O_SNFMT_WAN_MAC		5

/*
 * ================= Common structures =================
 */

/*
 * Standard I2O message frame.  All message frames begin with this.
 *
 * Bits  Field          Meaning
 * ----  -------------  ----------------------------------------------------
 * 0-2   msgflags       Message header version. Must be 001 (little endian).
 * 3     msgflags	Reserved.
 * 4-7   msgflags       Offset to SGLs expressed as # of 32-bit words.
 * 8-15  msgflags       Control flags.
 * 16-31 msgflags       Message frame size expressed as # of 32-bit words.
 * 0-11  msgfunc	TID of target.
 * 12-23 msgfunc        TID of initiator.
 * 24-31 msgfunc        Function (i.e., type of message).
 */
struct i2o_msg {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;	/* Initiator context */
	u_int32_t	msgtctx;	/* Transaction context */

	/* Message payload */

} __packed;

#define	I2O_MSGFLAGS_STATICMF		0x0100
#define	I2O_MSGFLAGS_64BIT		0x0200
#define	I2O_MSGFLAGS_MULTI		0x1000
#define	I2O_MSGFLAGS_FAIL		0x2000
#define	I2O_MSGFLAGS_LAST_REPLY		0x4000
#define	I2O_MSGFLAGS_REPLY		0x8000

/*
 * Standard reply frame.  msgflags, msgfunc, msgictx and msgtctx have the
 * same meaning as in `struct i2o_msg'.
 */
struct i2o_reply {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int16_t	detail;		/* Detailed status code */
	u_int8_t	reserved;
	u_int8_t	reqstatus;	/* Request status code */

	/* Reply payload */

} __packed;

/*
 * Fault notification reply, returned when a message frame can not be
 * processed (i.e I2O_MSGFLAGS_FAIL is set in the reply).
 */
struct i2o_fault_notify {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;	/* Not valid! */
	u_int8_t	lowestver;
	u_int8_t	highestver;
	u_int8_t	severity;
	u_int8_t	failurecode;
	u_int16_t	failingiop;	/* Bits 0-12 only */
	u_int16_t	failinghostunit;
	u_int32_t	agelimit;
	u_int32_t	lowmfa;
	u_int32_t	highmfa;
};

/*
 * Hardware resource table.  Not documented here.
 */
struct i2o_hrt_entry {
	u_int32_t	adapterid;
	u_int16_t	controllingtid;
	u_int8_t	busnumber;
	u_int8_t	bustype;
	u_int8_t	businfo[8];
} __packed;

struct i2o_hrt {
	u_int16_t	numentries;
	u_int8_t	entrysize;
	u_int8_t	hrtversion;
	u_int32_t	changeindicator;
	struct i2o_hrt_entry	entry[1];
} __packed;

/*
 * Logical configuration table entry.  Bitfields are broken down as follows:
 *
 * Bits   Field           Meaning
 * -----  --------------  ---------------------------------------------------
 *  0-11  classid         Class ID.
 * 12-15  classid         Class version.
 *  0-11  usertid         User TID
 * 12-23  usertid         Parent TID.
 * 24-31  usertid         BIOS info.
 */
struct i2o_lct_entry {
	u_int16_t	entrysize;
	u_int16_t	localtid;		/* Bits 0-12 only */
	u_int32_t	changeindicator;
	u_int32_t	deviceflags;
	u_int16_t	classid;
	u_int16_t	orgid;
	u_int32_t	subclassinfo;
	u_int32_t	usertid;
	u_int8_t	identitytag[8];
	u_int32_t	eventcaps;
} __packed;

/*
 * Logical configuration table header.
 */
struct i2o_lct {
	u_int16_t	tablesize;
	u_int16_t	flags;
	u_int32_t	iopflags;
	u_int32_t	changeindicator;
	struct i2o_lct_entry	entry[1];
} __packed;

/*
 * IOP system table.  Bitfields are broken down as follows:
 *
 * Bits   Field           Meaning
 * -----  --------------  ---------------------------------------------------
 *  0-11  iopid           IOP ID.
 * 12-31  iopid           Reserved.
 *  0-11  segnumber       Segment number.
 * 12-15  segnumber       I2O version.
 * 16-23  segnumber       IOP state.
 * 24-31  segnumber       Messenger type.
 */
struct i2o_systab_entry {
	u_int16_t	orgid;
	u_int16_t	reserved0;
	u_int32_t	iopid;
	u_int32_t	segnumber;
	u_int16_t	inboundmsgframesize;
	u_int16_t	reserved1;
	u_int32_t	lastchanged;
	u_int32_t	iopcaps;
	u_int32_t	inboundmsgportaddresslow;
	u_int32_t	inboundmsgportaddresshigh;
} __packed;

struct i2o_systab {
	u_int8_t	numentries;
	u_int8_t	version;
	u_int16_t	reserved0;
	u_int32_t	changeindicator;
	u_int32_t	reserved1[2];
	struct	i2o_systab_entry entry[1];
} __packed;

/*
 * IOP status record.  Bitfields are broken down as follows:
 *
 * Bits   Field           Meaning
 * -----  --------------  ---------------------------------------------------
 *  0-11  iopid           IOP ID.
 * 12-15  iopid           Reserved.
 * 16-31  iopid           Host unit ID.
 *  0-11  segnumber       Segment number.
 * 12-15  segnumber       I2O version.
 * 16-23  segnumber       IOP state.
 * 24-31  segnumber       Messenger type.
 */
struct i2o_status {
	u_int16_t	orgid;
	u_int16_t	reserved0;
	u_int32_t	iopid;
	u_int32_t	segnumber;
	u_int16_t	inboundmframesize;
	u_int8_t	initcode;
	u_int8_t	reserved1;
	u_int32_t	maxinboundmframes;
	u_int32_t	currentinboundmframes;
	u_int32_t	maxoutboundmframes;
	u_int8_t	productid[24];
	u_int32_t	expectedlctsize;
	u_int32_t	iopcaps;
	u_int32_t	desiredprivmemsize;
	u_int32_t	currentprivmemsize;
	u_int32_t	currentprivmembase;
	u_int32_t	desiredpriviosize;
	u_int32_t	currentpriviosize;
	u_int32_t	currentpriviobase;
	u_int8_t	reserved2[3];
	u_int8_t	syncbyte;
} __packed;

#define	I2O_IOP_STATE_INITIALIZING		0x01
#define	I2O_IOP_STATE_RESET			0x02
#define	I2O_IOP_STATE_HOLD			0x04
#define	I2O_IOP_STATE_READY			0x05
#define	I2O_IOP_STATE_OPERATIONAL		0x08
#define	I2O_IOP_STATE_FAILED			0x10
#define	I2O_IOP_STATE_FAULTED			0x11

/*
 * ================= Executive class messages =================
 */

#define	I2O_EXEC_STATUS_GET		0xa0
struct i2o_exec_status_get {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	reserved[4];
	u_int32_t	addrlow;
	u_int32_t	addrhigh;
	u_int32_t	length;
} __packed;

#define	I2O_EXEC_OUTBOUND_INIT		0xa1
struct i2o_exec_outbound_init {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	pagesize;
	u_int32_t	flags;		/* init code, outbound msg size */
} __packed;

#define	I2O_EXEC_OUTBOUND_INIT_IN_PROGRESS	1
#define	I2O_EXEC_OUTBOUND_INIT_REJECTED		2
#define	I2O_EXEC_OUTBOUND_INIT_FAILED		3
#define	I2O_EXEC_OUTBOUND_INIT_COMPLETE		4

#define	I2O_EXEC_LCT_NOTIFY		0xa2
struct i2o_exec_lct_notify {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	classid;
	u_int32_t	changeindicator;
} __packed;

#define	I2O_EXEC_SYS_TAB_SET		0xa3
struct i2o_exec_sys_tab_set {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	iopid;
	u_int32_t	segnumber;
} __packed;

#define	I2O_EXEC_HRT_GET		0xa8
struct i2o_exec_hrt_get {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
} __packed;

#define	I2O_EXEC_IOP_RESET		0xbd
struct i2o_exec_iop_reset {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	reserved[4];
	u_int32_t	statuslow;
	u_int32_t	statushigh;
} __packed;

#define	I2O_RESET_IN_PROGRESS		0x01
#define	I2O_RESET_REJECTED		0x02

/*
 * ================= Executive class parameter groups =================
 */

#define	I2O_PARAM_EXEC_LCT_SCALAR	0x0101
#define	I2O_PARAM_EXEC_LCT_TABLE	0x0102

/*
 * ================= HBA class messages =================
 */

#define	I2O_HBA_BUS_SCAN		0x89
struct i2o_hba_bus_scan {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
} __packed;

/*
 * ================= HBA class parameter groups =================
 */

#define	I2O_PARAM_HBA_CTLR_INFO		0x0000
struct i2o_param_hba_ctlr_info {
	u_int8_t	bustype;
	u_int8_t	busstate;
	u_int16_t	reserved;
	u_int8_t	busname[12];
} __packed;

#define	I2O_HBA_BUS_GENERIC		0x00
#define	I2O_HBA_BUS_SCSI		0x01
#define	I2O_HBA_BUS_FCA			0x10

#define	I2O_PARAM_HBA_SCSI_PORT_INFO	0x0001
struct i2o_param_hba_scsi_port_info {
	u_int8_t	physicalif;
	u_int8_t	electricalif;
	u_int8_t	isosynchonrous;
	u_int8_t	connectortype;
	u_int8_t	connectorgender;
	u_int8_t	reserved1;
	u_int16_t	reserved2;
	u_int32_t	maxnumberofdevices;
} __packed;

#define	I2O_PARAM_HBA_SCSI_PORT_GENERIC	0x01
#define	I2O_PARAM_HBA_SCSI_PORT_UNKNOWN	0x02
#define	I2O_PARAM_HBA_SCSI_PORT_PARINTF	0x03
#define	I2O_PARAM_HBA_SCSI_PORT_FCL	0x04
#define	I2O_PARAM_HBA_SCSI_PORT_1394	0x05
#define	I2O_PARAM_HBA_SCSI_PORT_SSA	0x06

#define	I2O_PARAM_HBA_SCSI_PORT_SE	0x03
#define	I2O_PARAM_HBA_SCSI_PORT_DIFF	0x04
#define	I2O_PARAM_HBA_SCSI_PORT_LVD	0x05
#define	I2O_PARAM_HBA_SCSI_PORT_OPTCL	0x06

#define	I2O_PARAM_HBA_SCSI_PORT_HDBS50	0x04
#define	I2O_PARAM_HBA_SCSI_PORT_HDBU50	0x05
#define	I2O_PARAM_HBA_SCSI_PORT_DBS50	0x06
#define	I2O_PARAM_HBA_SCSI_PORT_DBU50	0x07
#define	I2O_PARAM_HBA_SCSI_PORT_HDBS68	0x08
#define	I2O_PARAM_HBA_SCSI_PORT_HDBU68	0x09
#define	I2O_PARAM_HBA_SCSI_PORT_SCA1	0x0a
#define	I2O_PARAM_HBA_SCSI_PORT_SCA2	0x0b
#define	I2O_PARAM_HBA_SCSI_PORT_FCDB9	0x0c
#define	I2O_PARAM_HBA_SCSI_PORT_FC	0x0d
#define	I2O_PARAM_HBA_SCSI_PORT_FCSCA40	0x0e
#define	I2O_PARAM_HBA_SCSI_PORT_FCSCA20	0x0f
#define	I2O_PARAM_HBA_SCSI_PORT_FCBNC	0x10

#define	I2O_PARAM_HBA_SCSI_PORT_FEMALE	0x03
#define	I2O_PARAM_HBA_SCSI_PORT_MALE	0x04

#define	I2O_PARAM_HBA_SCSI_CTLR_INFO	0x0200
struct i2o_param_hba_scsi_ctlr_info {
	u_int8_t	scsitype;
	u_int8_t	protection;
	u_int8_t	settings;
	u_int8_t	reserved;
	u_int32_t	initiatorid;
	u_int64_t	scanlun0only;
	u_int16_t	disabledevice;
	u_int8_t	maxoffset;
	u_int8_t	maxdatawidth;
	u_int64_t	maxsyncrate;
} __packed;

/*
 * ================= Utility messages =================
 */

#define	I2O_UTIL_ABORT			0x01
struct i2o_util_abort {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	flags;		/* abort type and function type */
	u_int32_t	tctxabort;
} __packed;

#define	I2O_UTIL_ABORT_EXACT		0x00000000
#define	I2O_UTIL_ABORT_FUNCTION		0x00010000
#define	I2O_UTIL_ABORT_TRANSACTION	0x00020000
#define	I2O_UTIL_ABORT_WILD		0x00030000

#define	I2O_UTIL_ABORT_CLEAN		0x00040000

struct i2o_util_abort_reply {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	count;
} __packed;

#define	I2O_UTIL_PARAMS_SET		0x05
#define	I2O_UTIL_PARAMS_GET		0x06
struct i2o_util_params_op {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	flags;
} __packed;

#define	I2O_PARAMS_OP_FIELD_GET		1
#define	I2O_PARAMS_OP_LIST_GET		2
#define	I2O_PARAMS_OP_MORE_GET		3
#define	I2O_PARAMS_OP_SIZE_GET		4
#define	I2O_PARAMS_OP_TABLE_GET		5
#define	I2O_PARAMS_OP_FIELD_SET		6
#define	I2O_PARAMS_OP_LIST_SET		7
#define	I2O_PARAMS_OP_ROW_ADD		8
#define	I2O_PARAMS_OP_ROW_DELETE	9
#define	I2O_PARAMS_OP_TABLE_CLEAR	10

struct i2o_param_op_list_header {
	u_int16_t	count;
	u_int16_t	reserved;
} __packed;

struct i2o_param_op_all_template {
	u_int16_t	operation;
	u_int16_t	group;
	u_int16_t	fieldcount;
	u_int16_t	fields[1];
} __packed;

struct i2o_param_op_results {
	u_int16_t	count;
	u_int16_t	reserved;
} __packed;

struct i2o_param_read_results {
	u_int16_t	blocksize;
	u_int8_t	blockstatus;
	u_int8_t	errorinfosize;
} __packed;

struct i2o_param_table_results {
	u_int16_t	blocksize;
	u_int8_t	blockstatus;
	u_int8_t	errorinfosize;
	u_int16_t	rowcount;
	u_int16_t	moreflag;
} __packed;

#define	I2O_UTIL_CLAIM			0x09
struct i2o_util_claim {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	flags;
} __packed;

#define	I2O_UTIL_CLAIM_RESET_SENSITIVE		0x00000002
#define	I2O_UTIL_CLAIM_STATE_SENSITIVE		0x00000004
#define	I2O_UTIL_CLAIM_CAPACITY_SENSITIVE	0x00000008
#define	I2O_UTIL_CLAIM_NO_PEER_SERVICE		0x00000010
#define	I2O_UTIL_CLAIM_NO_MANAGEMENT_SERVICE	0x00000020

#define	I2O_UTIL_CLAIM_PRIMARY_USER		0x01000000
#define	I2O_UTIL_CLAIM_AUTHORIZED_USER		0x02000000
#define	I2O_UTIL_CLAIM_SECONDARY_USER		0x03000000
#define	I2O_UTIL_CLAIM_MANAGEMENT_USER		0x04000000

#define	I2O_UTIL_CLAIM_RELEASE		0x0b
struct i2o_util_claim_release {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	flags;		/* User flags as per I2O_UTIL_CLAIM */
} __packed;

#define	I2O_UTIL_CLAIM_RELEASE_CONDITIONAL	0x00000001

#define	I2O_UTIL_CONFIG_DIALOG		0x10
struct i2o_util_config_dialog {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	pageno;
} __packed;

#define	I2O_UTIL_EVENT_REGISTER		0x13
struct i2o_util_event_register {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	eventmask;
} __packed;

struct i2o_util_event_register_reply {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	event;
	u_int32_t	eventdata[1];
} __packed;

/* Generic events. */
#define	I2O_EVENT_GEN_DEVICE_STATE		0x00400000
#define	I2O_EVENT_GEN_VENDOR_EVENT		0x00800000
#define	I2O_EVENT_GEN_FIELD_MODIFIED		0x01000000
#define	I2O_EVENT_GEN_EVENT_MASK_MODIFIED	0x02000000
#define	I2O_EVENT_GEN_DEVICE_RESET		0x04000000
#define	I2O_EVENT_GEN_CAPABILITY_CHANGE		0x08000000
#define	I2O_EVENT_GEN_LOCK_RELEASE		0x10000000
#define	I2O_EVENT_GEN_NEED_CONFIGURATION	0x20000000
#define	I2O_EVENT_GEN_GENERAL_WARNING		0x40000000
#define	I2O_EVENT_GEN_STATE_CHANGE		0x80000000

/* Executive class events. */
#define	I2O_EVENT_EXEC_RESOURCE_LIMITS		0x00000001
#define	I2O_EVENT_EXEC_CONNECTION_FAIL		0x00000002
#define	I2O_EVENT_EXEC_ADAPTER_FAULT		0x00000004
#define	I2O_EVENT_EXEC_POWER_FAIL		0x00000008
#define	I2O_EVENT_EXEC_RESET_PENDING		0x00000010
#define	I2O_EVENT_EXEC_RESET_IMMINENT		0x00000020
#define	I2O_EVENT_EXEC_HARDWARE_FAIL		0x00000040
#define	I2O_EVENT_EXEC_XCT_CHANGE		0x00000080
#define	I2O_EVENT_EXEC_NEW_LCT_ENTRY		0x00000100
#define	I2O_EVENT_EXEC_MODIFIED_LCT		0x00000200
#define	I2O_EVENT_EXEC_DDM_AVAILIBILITY		0x00000400

/* LAN class events. */
#define	I2O_EVENT_LAN_LINK_DOWN			0x00000001
#define	I2O_EVENT_LAN_LINK_UP			0x00000002
#define	I2O_EVENT_LAN_MEDIA_CHANGE		0x00000004

/*
 * ================= Utility parameter groups =================
 */

#define	I2O_PARAM_DEVICE_IDENTITY	0xf100
struct i2o_param_device_identity {
	u_int32_t	classid;
	u_int16_t	ownertid;
	u_int16_t	parenttid;
	u_int8_t	vendorinfo[16];
	u_int8_t	productinfo[16];
	u_int8_t	description[16];
	u_int8_t	revlevel[8];
	u_int8_t	snformat;
	u_int8_t	serialnumber[1];
} __packed;

#define	I2O_PARAM_DDM_IDENTITY		0xf101
struct i2o_param_ddm_identity {
	u_int16_t	ddmtid;
	u_int8_t	name[24];
	u_int8_t	revlevel[8];
	u_int8_t	snformat;
	u_int8_t	serialnumber[12];
} __packed;

/*
 * ================= Block storage class messages =================
 */

#define	I2O_RBS_BLOCK_READ		0x30
struct i2o_rbs_block_read {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	flags;		/* flags, time multiplier, read ahead */
	u_int32_t	datasize;
	u_int32_t	lowoffset;
	u_int32_t	highoffset;
} __packed;

#define	I2O_RBS_BLOCK_READ_NO_RETRY	0x01
#define	I2O_RBS_BLOCK_READ_SOLO		0x02
#define	I2O_RBS_BLOCK_READ_CACHE_READ	0x04
#define	I2O_RBS_BLOCK_READ_PREFETCH	0x08
#define	I2O_RBS_BLOCK_READ_CACHE_ONLY	0x10

#define	I2O_RBS_BLOCK_WRITE             0x31
struct i2o_rbs_block_write {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	flags;		/* flags, time multiplier */
	u_int32_t	datasize;
	u_int32_t	lowoffset;
	u_int32_t	highoffset;
} __packed;

#define	I2O_RBS_BLOCK_WRITE_NO_RETRY	0x01
#define	I2O_RBS_BLOCK_WRITE_SOLO	0x02
#define	I2O_RBS_BLOCK_WRITE_CACHE_NONE	0x04
#define	I2O_RBS_BLOCK_WRITE_CACHE_WT	0x08
#define	I2O_RBS_BLOCK_WRITE_CACHE_WB	0x10

#define	I2O_RBS_CACHE_FLUSH             0x37
struct i2o_rbs_cache_flush {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	flags;		/* flags, time multiplier */
} __packed;

#define	I2O_RBS_MEDIA_MOUNT		0x41
struct i2o_rbs_media_mount {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	mediaid;
	u_int32_t	loadflags;
} __packed;

#define	I2O_RBS_MEDIA_EJECT             0x43
struct i2o_rbs_media_eject {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	mediaid;
} __packed;

#define	I2O_RBS_MEDIA_LOCK		0x49
struct i2o_rbs_media_lock {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	mediaid;
} __packed;

#define	I2O_RBS_MEDIA_UNLOCK		0x4b
struct i2o_rbs_media_unlock {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	mediaid;
} __packed;

/* Standard RBS reply frame. */
struct i2o_rbs_reply {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int16_t	detail;
	u_int8_t	retrycount;
	u_int8_t	reqstatus;
	u_int32_t	transfercount;
	u_int64_t	offset;		/* Error replies only */
} __packed;

/*
 * ================= Block storage class parameter groups =================
 */

#define	I2O_PARAM_RBS_DEVICE_INFO	0x0000
struct i2o_param_rbs_device_info {
	u_int8_t	type;
	u_int8_t	npaths;
	u_int16_t	powerstate;
	u_int32_t	blocksize;
	u_int64_t	capacity;
	u_int32_t	capabilities;
	u_int32_t	state;
} __packed;

#define	I2O_RBS_TYPE_DIRECT		0x00
#define	I2O_RBS_TYPE_WORM		0x04
#define	I2O_RBS_TYPE_CDROM		0x05
#define	I2O_RBS_TYPE_OPTICAL		0x07

#define	I2O_RBS_CAP_CACHING		0x00000001
#define	I2O_RBS_CAP_MULTI_PATH		0x00000002
#define	I2O_RBS_CAP_DYNAMIC_CAPACITY	0x00000004
#define	I2O_RBS_CAP_REMOVABLE_MEDIA	0x00000008
#define	I2O_RBS_CAP_REMOVABLE_DEVICE	0x00000010
#define	I2O_RBS_CAP_READ_ONLY		0x00000020
#define	I2O_RBS_CAP_LOCKOUT		0x00000040
#define	I2O_RBS_CAP_BOOT_BYPASS		0x00000080
#define	I2O_RBS_CAP_COMPRESSION		0x00000100
#define	I2O_RBS_CAP_DATA_SECURITY	0x00000200
#define	I2O_RBS_CAP_RAID		0x00000400

#define	I2O_RBS_STATE_CACHING		0x00000001
#define	I2O_RBS_STATE_POWERED_ON	0x00000002
#define	I2O_RBS_STATE_READY		0x00000004
#define	I2O_RBS_STATE_MEDIA_LOADED	0x00000008
#define	I2O_RBS_STATE_DEVICE_LOADED	0x00000010
#define	I2O_RBS_STATE_READ_ONLY		0x00000020
#define	I2O_RBS_STATE_LOCKOUT		0x00000040
#define	I2O_RBS_STATE_BOOT_BYPASS	0x00000080
#define	I2O_RBS_STATE_COMPRESSION	0x00000100
#define	I2O_RBS_STATE_DATA_SECURITY	0x00000200
#define	I2O_RBS_STATE_RAID		0x00000400

#define	I2O_PARAM_RBS_OPERATION		0x0001
struct i2o_param_rbs_operation {
	u_int8_t	autoreass;
	u_int8_t	reasstolerance;
	u_int8_t	numretries;
	u_int8_t	reserved0;
	u_int32_t	reasssize;
	u_int32_t	expectedtimeout;
	u_int32_t	rwvtimeout;
	u_int32_t	rwvtimeoutbase;
	u_int32_t	timeoutbase;
	u_int32_t	orderedreqdepth;
	u_int32_t	atomicwritesize;
} __packed;

#define	I2O_PARAM_RBS_OPERATION_autoreass		0
#define	I2O_PARAM_RBS_OPERATION_reasstolerance		1
#define	I2O_PARAM_RBS_OPERATION_numretries		2
#define	I2O_PARAM_RBS_OPERATION_reserved0		3
#define	I2O_PARAM_RBS_OPERATION_reasssize		4
#define	I2O_PARAM_RBS_OPERATION_expectedtimeout		5
#define	I2O_PARAM_RBS_OPERATION_rwvtimeout		6
#define	I2O_PARAM_RBS_OPERATION_rwvtimeoutbase		7
#define	I2O_PARAM_RBS_OPERATION_timeoutbase		8
#define	I2O_PARAM_RBS_OPERATION_orderedreqdepth		9
#define	I2O_PARAM_RBS_OPERATION_atomicwritesize		10

#define	I2O_PARAM_RBS_CACHE_CONTROL	0x0003
struct i2o_param_rbs_cache_control {
	u_int32_t	totalcachesize;
	u_int32_t	readcachesize;
	u_int32_t	writecachesize;
	u_int8_t	writepolicy;
	u_int8_t	readpolicy;
	u_int8_t	errorcorrection;
	u_int8_t	reserved;
} __packed;

/*
 * ================= SCSI peripheral class messages =================
 */

#define	I2O_SCSI_DEVICE_RESET		0x27
struct i2o_scsi_device_reset {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
} __packed;

#define	I2O_SCSI_SCB_EXEC		0x81
struct i2o_scsi_scb_exec {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	flags;		/* CDB length and flags */
	u_int8_t	cdb[16];
	u_int32_t	datalen;
} __packed;

#define	I2O_SCB_FLAG_SENSE_DATA_IN_MESSAGE  0x00200000
#define	I2O_SCB_FLAG_SENSE_DATA_IN_BUFFER   0x00600000
#define	I2O_SCB_FLAG_SIMPLE_QUEUE_TAG       0x00800000
#define	I2O_SCB_FLAG_HEAD_QUEUE_TAG         0x01000000
#define	I2O_SCB_FLAG_ORDERED_QUEUE_TAG      0x01800000
#define	I2O_SCB_FLAG_ACA_QUEUE_TAG          0x02000000
#define	I2O_SCB_FLAG_ENABLE_DISCONNECT      0x20000000
#define	I2O_SCB_FLAG_XFER_FROM_DEVICE       0x40000000
#define	I2O_SCB_FLAG_XFER_TO_DEVICE         0x80000000

#define	I2O_SCSI_SCB_ABORT		0x83
struct i2o_scsi_scb_abort {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int32_t	tctxabort;
} __packed;

struct i2o_scsi_reply {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	msgtctx;
	u_int8_t	scsistatus;
	u_int8_t	hbastatus;
	u_int8_t	reserved;
	u_int8_t	reqstatus;
	u_int32_t	datalen;
	u_int32_t	senselen;
	u_int8_t	sense[40];
} __packed;

#define	I2O_SCSI_DSC_SUCCESS                0x00
#define	I2O_SCSI_DSC_REQUEST_ABORTED        0x02
#define	I2O_SCSI_DSC_UNABLE_TO_ABORT        0x03
#define	I2O_SCSI_DSC_COMPLETE_WITH_ERROR    0x04
#define	I2O_SCSI_DSC_ADAPTER_BUSY           0x05
#define	I2O_SCSI_DSC_REQUEST_INVALID        0x06
#define	I2O_SCSI_DSC_PATH_INVALID           0x07
#define	I2O_SCSI_DSC_DEVICE_NOT_PRESENT     0x08
#define	I2O_SCSI_DSC_UNABLE_TO_TERMINATE    0x09
#define	I2O_SCSI_DSC_SELECTION_TIMEOUT      0x0a
#define	I2O_SCSI_DSC_COMMAND_TIMEOUT        0x0b
#define	I2O_SCSI_DSC_MR_MESSAGE_RECEIVED    0x0d
#define	I2O_SCSI_DSC_SCSI_BUS_RESET         0x0e
#define	I2O_SCSI_DSC_PARITY_ERROR_FAILURE   0x0f
#define	I2O_SCSI_DSC_AUTOSENSE_FAILED       0x10
#define	I2O_SCSI_DSC_NO_ADAPTER             0x11
#define	I2O_SCSI_DSC_DATA_OVERRUN           0x12
#define	I2O_SCSI_DSC_UNEXPECTED_BUS_FREE    0x13
#define	I2O_SCSI_DSC_SEQUENCE_FAILURE       0x14
#define	I2O_SCSI_DSC_REQUEST_LENGTH_ERROR   0x15
#define	I2O_SCSI_DSC_PROVIDE_FAILURE        0x16
#define	I2O_SCSI_DSC_BDR_MESSAGE_SENT       0x17
#define	I2O_SCSI_DSC_REQUEST_TERMINATED     0x18
#define	I2O_SCSI_DSC_IDE_MESSAGE_SENT       0x33
#define	I2O_SCSI_DSC_RESOURCE_UNAVAILABLE   0x34
#define	I2O_SCSI_DSC_UNACKNOWLEDGED_EVENT   0x35
#define	I2O_SCSI_DSC_MESSAGE_RECEIVED       0x36
#define	I2O_SCSI_DSC_INVALID_CDB            0x37
#define	I2O_SCSI_DSC_LUN_INVALID            0x38
#define	I2O_SCSI_DSC_SCSI_TID_INVALID       0x39
#define	I2O_SCSI_DSC_FUNCTION_UNAVAILABLE   0x3a
#define	I2O_SCSI_DSC_NO_NEXUS               0x3b
#define	I2O_SCSI_DSC_SCSI_IID_INVALID       0x3c
#define	I2O_SCSI_DSC_CDB_RECEIVED           0x3d
#define	I2O_SCSI_DSC_LUN_ALREADY_ENABLED    0x3e
#define	I2O_SCSI_DSC_BUS_BUSY               0x3f
#define	I2O_SCSI_DSC_QUEUE_FROZEN           0x40

/*
 * ================= SCSI peripheral class parameter groups =================
 */

#define	I2O_PARAM_SCSI_DEVICE_INFO	0x0000
struct i2o_param_scsi_device_info {
	u_int8_t	devicetype;
	u_int8_t	flags;
	u_int16_t	reserved0;
	u_int32_t	identifier;
	u_int8_t	luninfo[8];
	u_int32_t	queuedepth;
	u_int8_t	reserved1;
	u_int8_t	negoffset;
	u_int8_t	negdatawidth;
	u_int8_t	reserved2;
	u_int64_t	negsyncrate;
} __packed;

/*
 * ================= LAN class messages =================
 */

#define	I2O_LAN_PACKET_SEND		0x3b
struct i2o_lan_packet_send {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	tcw;

	/* SGL follows */
} __packed;

#define	I2O_LAN_TCW_ACCESS_PRI_MASK	0x00000007
#define	I2O_LAN_TCW_SUPPRESS_CRC	0x00000008
#define	I2O_LAN_TCW_SUPPRESS_LOOPBACK	0x00000010
#define	I2O_LAN_TCW_CKSUM_NETWORK	0x00000020
#define	I2O_LAN_TCW_CKSUM_TRANSPORT	0x00000040
#define	I2O_LAN_TCW_REPLY_BATCH		0x00000000
#define	I2O_LAN_TCW_REPLY_IMMEDIATELY	0x40000000
#define	I2O_LAN_TCW_REPLY_UNSUCCESSFUL	0x80000000
#define	I2O_LAN_TCW_REPLY_NONE		0xc0000000

#define	I2O_LAN_SDU_SEND		0x3d
struct i2o_lan_sdu_send {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	tcw;		/* As per PACKET_SEND. */

	/* SGL follows */
} __packed;

struct i2o_lan_send_reply {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	trl;
	u_int16_t	detail;
	u_int8_t	reserved;
	u_int8_t	reqstatus;
	u_int32_t	tctx[1];
} __packed;

#define	I2O_LAN_RECEIVE_POST		0x3e
struct i2o_lan_receive_post {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int32_t	bktcnt;

	/* SGL follows */
} __packed;

struct i2o_lan_receive_reply {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int8_t	trlcount;
	u_int8_t	trlesize;
	u_int8_t	reserved;
	u_int8_t	trlflags;
	u_int32_t	bucketsleft;
} __packed;

#define	I2O_LAN_RECEIVE_REPLY_PDB	0x80

#define	I2O_LAN_PDB_ERROR_NONE		0x00
#define	I2O_LAN_PDB_ERROR_BAD_CRC	0x01
#define	I2O_LAN_PDB_ERROR_ALIGNMENT	0x02
#define	I2O_LAN_PDB_ERROR_TOO_LONG	0x03
#define	I2O_LAN_PDB_ERROR_TOO_SHORT	0x04
#define	I2O_LAN_PDB_ERROR_RX_OVERRUN	0x05
#define	I2O_LAN_PDB_ERROR_L3_CKSUM_BAD	0x40
#define	I2O_LAN_PDB_ERROR_L4_CKSUM_BAD	0x80
#define	I2O_LAN_PDB_ERROR_CKSUM_MASK	0xc0
#define	I2O_LAN_PDB_ERROR_OTHER		0xff

#define	I2O_LAN_RESET			0x35
struct i2o_lan_reset {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int16_t	reserved;
	u_int16_t	resrcflags;
} __packed;

#define	I2O_LAN_RESRC_RETURN_BUCKETS	0x0001
#define	I2O_LAN_RESRC_RETURN_XMITS	0x0002

#define	I2O_LAN_SUSPEND			0x37
struct i2o_lan_suspend {
	u_int32_t	msgflags;
	u_int32_t	msgfunc;
	u_int32_t	msgictx;
	u_int16_t	reserved;
	u_int16_t	resrcflags;	/* As per RESET. */
} __packed;

#define	I2O_LAN_DSC_SUCCESS			0x00
#define	I2O_LAN_DSC_DEVICE_FAILURE		0x01
#define	I2O_LAN_DSC_DESTINATION_NOT_FOUND	0x02
#define	I2O_LAN_DSC_TRANSMIT_ERROR		0x03
#define	I2O_LAN_DSC_TRANSMIT_ABORTED		0x04
#define	I2O_LAN_DSC_RECEIVE_ERROR		0x05
#define	I2O_LAN_DSC_RECEIVE_ABORTED		0x06
#define	I2O_LAN_DSC_DMA_ERROR			0x07
#define	I2O_LAN_DSC_BAD_PACKET_DETECTED		0x08
#define	I2O_LAN_DSC_OUT_OF_MEMORY		0x09
#define	I2O_LAN_DSC_BUCKET_OVERRUN		0x0a
#define	I2O_LAN_DSC_IOP_INTERNAL_ERROR		0x0b
#define	I2O_LAN_DSC_CANCELED			0x0c
#define	I2O_LAN_DSC_INVALID_TRANSACTION_CONTEXT	0x0d
#define	I2O_LAN_DSC_DEST_ADDRESS_DETECTED	0x0e
#define	I2O_LAN_DSC_DEST_ADDRESS_OMITTED	0x0f
#define	I2O_LAN_DSC_PARTIAL_PACKET_RETURNED	0x10
#define	I2O_LAN_DSC_TEMP_SUSPENDED_STATE	0x11

/*
 * ================= LAN class parameter groups =================
 */

#define	I2O_PARAM_LAN_DEVICE_INFO	0x0000
struct i2o_param_lan_device_info {
	u_int16_t	lantype;
	u_int16_t	flags;
	u_int8_t	addrfmt;
	u_int8_t	reserved1;
	u_int16_t	reserved2;
	u_int32_t	minpktsize;
	u_int32_t	maxpktsize;
	u_int8_t	hwaddr[8];
	u_int64_t	maxtxbps;
	u_int64_t	maxrxbps;
} __packed;

#define	I2O_LAN_TYPE_ETHERNET		0x0030
#define	I2O_LAN_TYPE_100BASEVG		0x0040
#define	I2O_LAN_TYPE_TOKEN_RING		0x0050
#define	I2O_LAN_TYPE_FDDI		0x0060
#define	I2O_LAN_TYPE_FIBRECHANNEL	0x0070

#define	I2O_PARAM_LAN_MAC_ADDRESS	0x0001
struct i2o_param_lan_mac_address {
	u_int8_t	activeaddr[8];
	u_int8_t	localaddr[8];
	u_int8_t	addrmask[8];
	u_int32_t	filtermask;
	u_int32_t	hwfiltercaps;
	u_int32_t	maxmcastaddr;
	u_int32_t	maxfilterperfect;
	u_int32_t	maxfilterimperfect;
} __packed;

#define	I2O_PARAM_LAN_MAC_ADDRESS_activeaddr		0
#define	I2O_PARAM_LAN_MAC_ADDRESS_localaddr		1
#define	I2O_PARAM_LAN_MAC_ADDRESS_addrmask		2
#define	I2O_PARAM_LAN_MAC_ADDRESS_filtermask		3
#define	I2O_PARAM_LAN_MAC_ADDRESS_hwfiltercaps		4
#define	I2O_PARAM_LAN_MAC_ADDRESS_maxmcastaddr		5
#define	I2O_PARAM_LAN_MAC_ADDRESS_maxfilterperfect	6
#define	I2O_PARAM_LAN_MAC_ADDRESS_maxfilterimperfect	7

#define	I2O_LAN_FILTERMASK_UNICAST_DISABLE	0x0001
#define	I2O_LAN_FILTERMASK_PROMISC_ENABLE	0x0002
#define	I2O_LAN_FILTERMASK_PROMISC_MCAST_ENABLE	0x0004
#define	I2O_LAN_FILTERMASK_BROADCAST_DISABLE	0x0100
#define	I2O_LAN_FILTERMASK_MCAST_DISABLE	0x0200
#define	I2O_LAN_FILTERMASK_FUNCADDR_DISABLE	0x0400
#define	I2O_LAN_FILTERMASK_MACMODE_0		0x0800
#define	I2O_LAN_FILTERMASK_MACMODE_1		0x1000

#define	I2O_PARAM_LAN_MCAST_MAC_ADDRESS	0x0002
/*
 * This one's a table, not a scalar.
 */

#define	I2O_PARAM_LAN_BATCH_CONTROL	0x0003
struct i2o_param_lan_batch_control {
	u_int32_t	batchflags;
	u_int32_t	risingloaddly;		/* 1.5 only */
	u_int32_t	risingloadthresh;	/* 1.5 only */
	u_int32_t	fallingloaddly;		/* 1.5 only */
	u_int32_t	fallingloadthresh;	/* 1.5 only */
	u_int32_t	maxrxbatchcount;
	u_int32_t	maxrxbatchdelay;
	u_int32_t	maxtxbatchdelay;	/* 2.0 (conflict with 1.5) */
	u_int32_t	maxtxbatchcount;	/* 2.0 only */
} __packed;

#define	I2O_PARAM_LAN_BATCH_CONTROL_batchflags		0
#define	I2O_PARAM_LAN_BATCH_CONTROL_risingloaddly	1
#define	I2O_PARAM_LAN_BATCH_CONTROL_risingloadthresh	2
#define	I2O_PARAM_LAN_BATCH_CONTROL_fallingloaddly	3
#define	I2O_PARAM_LAN_BATCH_CONTROL_fallingloadthresh	4
#define	I2O_PARAM_LAN_BATCH_CONTROL_maxrxbatchcount	5
#define	I2O_PARAM_LAN_BATCH_CONTROL_maxrxbatchdelay	6
#define	I2O_PARAM_LAN_BATCH_CONTROL_maxtxbatchdelay	7
#define	I2O_PARAM_LAN_BATCH_CONTROL_maxtxbatchcount	8

#define	I2O_PARAM_LAN_OPERATION		0x0004
struct i2o_param_lan_operation {
	u_int32_t	pktprepad;
	u_int32_t	userflags;
	u_int32_t	pktorphanlimit;
	u_int32_t	txmodesenable;		/* 2.0 only */
	u_int32_t	rxmodesenable;		/* 2.0 only */
} __packed;

#define	I2O_PARAM_LAN_OPERATION_pktprepad		0
#define	I2O_PARAM_LAN_OPERATION_userflags		1
#define	I2O_PARAM_LAN_OPERATION_pktorphanlimit		2
#define	I2O_PARAM_LAN_OPERATION_txmodesenable		3
#define	I2O_PARAM_LAN_OPERATION_rxmodesenable		4

#define	I2O_PARAM_LAN_MEDIA_OPERATION	0x0005
struct i2o_param_lan_media_operation {
	u_int32_t	connectortype;
	u_int32_t	connectiontype;
	u_int32_t	curtxbps;
	u_int32_t	currxbps;
	u_int8_t	fullduplex;
	u_int8_t	linkstatus;
	u_int8_t	badpkthandling;		/* v1.5 only */
	u_int8_t	duplextarget;		/* v2.0 only */
	u_int32_t	connectortarget;	/* v2.0 only */
	u_int32_t	connectiontarget;	/* v2.0 only */
} __packed;

#define	I2O_PARAM_LAN_MEDIA_OPERATION_connectortype	0
#define	I2O_PARAM_LAN_MEDIA_OPERATION_connectiontype	1
#define	I2O_PARAM_LAN_MEDIA_OPERATION_curtxbps		2
#define	I2O_PARAM_LAN_MEDIA_OPERATION_currxbps		3
#define	I2O_PARAM_LAN_MEDIA_OPERATION_fullduplex	4
#define	I2O_PARAM_LAN_MEDIA_OPERATION_linkstatus	5
#define	I2O_PARAM_LAN_MEDIA_OPERATION_badpkthandling	6
#define	I2O_PARAM_LAN_MEDIA_OPERATION_duplextarget	7
#define	I2O_PARAM_LAN_MEDIA_OPERATION_connectortarget	8
#define	I2O_PARAM_LAN_MEDIA_OPERATION_connectiontarget	9

#define	I2O_LAN_CONNECTOR_OTHER		0x00
#define	I2O_LAN_CONNECTOR_UNKNOWN	0x01
#define	I2O_LAN_CONNECTOR_AUI		0x02
#define	I2O_LAN_CONNECTOR_UTP		0x03
#define	I2O_LAN_CONNECTOR_BNC		0x04
#define	I2O_LAN_CONNECTOR_RJ45		0x05
#define	I2O_LAN_CONNECTOR_STP_DB9	0x06
#define	I2O_LAN_CONNECTOR_FIBER_MIC	0x07
#define	I2O_LAN_CONNECTOR_APPLE_AUI	0x08
#define	I2O_LAN_CONNECTOR_MII		0x09
#define	I2O_LAN_CONNECTOR_COPPER_DB9	0x0a
#define	I2O_LAN_CONNECTOR_COPPER_AW	0x0b
#define	I2O_LAN_CONNECTOR_OPTICAL_LW	0x0c
#define	I2O_LAN_CONNECTOR_SIP		0x0d
#define	I2O_LAN_CONNECTOR_OPTICAL_SW	0x0e

#define	I2O_LAN_CONNECTION_UNKNOWN		0x0000

#define	I2O_LAN_CONNECTION_ETHERNET_AUI		0x0301
#define	I2O_LAN_CONNECTION_ETHERNET_10BASE5	0x0302
#define	I2O_LAN_CONNECTION_ETHERNET_FOIRL	0x0303
#define	I2O_LAN_CONNECTION_ETHERNET_10BASE2	0x0304
#define	I2O_LAN_CONNECTION_ETHERNET_10BROAD36	0x0305
#define	I2O_LAN_CONNECTION_ETHERNET_10BASET	0x0306
#define	I2O_LAN_CONNECTION_ETHERNET_10BASEFP	0x0307
#define	I2O_LAN_CONNECTION_ETHERNET_10BASEFB	0x0308
#define	I2O_LAN_CONNECTION_ETHERNET_10BASEFL	0x0309
#define	I2O_LAN_CONNECTION_ETHERNET_100BASETX	0x030a
#define	I2O_LAN_CONNECTION_ETHERNET_100BASEFX	0x030b
#define	I2O_LAN_CONNECTION_ETHERNET_100BASET4	0x030c
#define	I2O_LAN_CONNECTION_ETHERNET_1000BASESX	0x030d
#define	I2O_LAN_CONNECTION_ETHERNET_1000BASELX	0x030e
#define	I2O_LAN_CONNECTION_ETHERNET_1000BASECX	0x030f
#define	I2O_LAN_CONNECTION_ETHERNET_1000BASET	0x0310

#define	I2O_LAN_CONNECTION_100BASEVG_ETHERNET	0x0401
#define	I2O_LAN_CONNECTION_100BASEVG_TOKEN_RING	0x0402

#define	I2O_LAN_CONNECTION_TOKEN_RING_4MBIT	0x0501
#define	I2O_LAN_CONNECTION_TOKEN_RING_16MBIT	0x0502

#define	I2O_LAN_CONNECTION_FDDI_125MBIT		0x0601

#define	I2O_LAN_CONNECTION_FIBRECHANNEL_P2P	0x0701
#define	I2O_LAN_CONNECTION_FIBRECHANNEL_AL	0x0702
#define	I2O_LAN_CONNECTION_FIBRECHANNEL_PL	0x0703
#define	I2O_LAN_CONNECTION_FIBRECHANNEL_F	0x0704

#define	I2O_LAN_CONNECTION_OTHER_EMULATED	0x0f00
#define	I2O_LAN_CONNECTION_OTHER_OTHER		0x0f01

#define	I2O_LAN_CONNECTION_DEFAULT		0xffffffff

#define	I2O_PARAM_LAN_TRANSMIT_INFO	0x0007
struct i2o_param_lan_transmit_info {
	u_int32_t	maxpktsg;
	u_int32_t	maxchainsg;
	u_int32_t	maxoutstanding;
	u_int32_t	maxpktsout;
	u_int32_t	maxpktsreq;
	u_int32_t	txmodes;
} __packed;

#define	I2O_LAN_MODES_NO_DA_IN_SGL		0x0002
#define	I2O_LAN_MODES_CRC_SUPPRESSION		0x0004
#define	I2O_LAN_MODES_LOOPBACK_SUPPRESSION	0x0004	/* 1.5 only */
#define	I2O_LAN_MODES_FCS_RECEPTION		0x0008	/* 2.0 only */
#define	I2O_LAN_MODES_MAC_INSERTION		0x0010
#define	I2O_LAN_MODES_RIF_INSERTION		0x0020
#define	I2O_LAN_MODES_IPV4_CHECKSUM		0x0100	/* 2.0 only */
#define	I2O_LAN_MODES_TCP_CHECKSUM		0x0200	/* 2.0 only */
#define	I2O_LAN_MODES_UDP_CHECKSUM		0x0400	/* 2.0 only */
#define	I2O_LAN_MODES_RSVP_CHECKSUM		0x0800	/* 2.0 only */
#define	I2O_LAN_MODES_ICMP_CHECKSUM		0x1000	/* 2.0 only */

#define	I2O_PARAM_LAN_RECEIVE_INFO	0x0008
struct i2o_param_lan_receive_info {
	u_int32_t	maxchain;
	u_int32_t	maxbuckets;
} __packed;

#define	I2O_PARAM_LAN_STATS		0x0009
struct i2o_param_lan_stats {
	u_int64_t	opackets;
	u_int64_t	obytes;
	u_int64_t	ipackets;
	u_int64_t	oerrors;
	u_int64_t	ierrors;
	u_int64_t	rxnobuffer;
	u_int64_t	resetcount;
} __packed;

#define	I2O_PARAM_LAN_802_3_STATS	0x0200
struct i2o_param_lan_802_3_stats {
	u_int64_t	alignmenterror;
	u_int64_t	onecollision;
	u_int64_t	manycollisions;
	u_int64_t	deferred;
	u_int64_t	latecollision;
	u_int64_t	maxcollisions;
	u_int64_t	carrierlost;
	u_int64_t	excessivedeferrals;
} __packed;

#define	I2O_PARAM_LAN_FDDI_STATS	0x0400
struct i2o_param_lan_fddi_stats {
	u_int64_t	configstate;
	u_int64_t	upstreamnode;
	u_int64_t	downstreamnode;
	u_int64_t	frameerrors;
	u_int64_t	frameslost;
	u_int64_t	ringmgmtstate;
	u_int64_t	lctfailures;
	u_int64_t	lemrejects;
	u_int64_t	lemcount;
	u_int64_t	lconnectionstate;
} __packed;

#endif	/* !defined _I2O_I2O_H_ */