/*	$NetBSD: scsi_spc.h,v 1.7 2022/01/27 18:37:02 jakllsch Exp $	*/

/*-
 * Copyright (c) 2005 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
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
 * SCSI Primary Commands (SPC) --
 *	Commands for all device types
 */

/*
 * Largely written by Julian Elischer (julian@tfs.com)
 * for TRW Financial Systems.
 *
 * TRW Financial Systems, in accordance with their agreement with Carnegie
 * Mellon University, makes this software available to CMU to distribute
 * or use in any manner that they see fit as long as this message is kept with
 * the software. For this reason TFS also grants any other persons or
 * organisations permission to use or modify this software.
 *
 * TFS supplies this software to be publicly redistributed
 * on the understanding that TFS is not responsible for the correct
 * functioning of this software in any circumstances.
 *
 * Ported to run under 386BSD by Julian Elischer (julian@tfs.com) Sept 1992
 */

#ifndef _DEV_SCSIPI_SCSI_SPC_H_
#define	_DEV_SCSIPI_SCSI_SPC_H_

/*
 * EXTENDED COPY
 */

/*
 * INQUIRY
 */

/*
 * LOG SELECT
 */

/*
 * LOG SENSE
 */

/*
 * MODE SELECT
 */

#define	SCSI_MODE_SELECT_6		0x15
struct scsi_mode_select_6 {
	uint8_t opcode;
	uint8_t byte2;
#define	SMS_SP		0x01	/* save page */
#define	SMS_PF		0x10	/* page format (0 = SCSI-1, 1 = SCSI-2) */
	uint8_t reserved[2];
	uint8_t length;
	uint8_t control;
};

#define	SCSI_MODE_SELECT_10		0x55
struct scsi_mode_select_10 {
	uint8_t opcode;
	uint8_t byte2;		/* see MODE SELECT (6) */
	uint8_t reserved[5];
	uint8_t length[2];
	uint8_t control;
};

/*
 * MODE SENSE
 */

#define	SCSI_MODE_SENSE_6		0x1a
struct scsi_mode_sense_6 {
	uint8_t opcode;
	uint8_t byte2;
#define	SMS_DBD				0x08 /* disable block descriptors */
	uint8_t page;
#define	SMS_PAGE_MASK			0x3f
#define	SMS_PCTRL_MASK			0xc0
#define	SMS_PCTRL_CURRENT		0x00
#define	SMS_PCTRL_CHANGEABLE		0x40
#define	SMS_PCTRL_DEFAULT		0x80
#define	SMS_PCTRL_SAVED			0xc0
	uint8_t reserved;
	uint8_t length;
	uint8_t control;
};

#define	SCSI_MODE_SENSE_10		0x5a
struct scsi_mode_sense_10 {
	uint8_t opcode;
	uint8_t byte2;			/* see MODE SENSE (6) */
#define	SMS_LLBAA			0x10
	uint8_t page;			/* See MODE SENSE (6) */
	uint8_t reserved[4];
	uint8_t length[2];
	uint8_t control;
};

/*
 * Page code usage:
 *	0x00		Vendor-specific (does not require page format)
 *	0x01 - 0x1f	Device-type-specific pages
 *	0x20 - 0x3e	Vendor-specific (page format required)
 *	0x3f		Return all mode pages
 */
#define	SMS_PAGE_ALL_PAGES		0x3f

/*
 * Mode parameters are returned in the following format:
 *
 *	Mode parameter header
 *	Block descriptor(s)	[zero or more]
 *	Page(s)			[zero or more, variable-length]
 */

struct scsi_mode_parameter_header_6 {
	uint8_t data_length;
	uint8_t medium_type;
	uint8_t dev_spec;
	uint8_t blk_desc_len;		/* unused on ATAPI */
};

struct scsi_mode_parameter_header_10 {
	uint8_t data_length[2];
	uint8_t medium_type;
	uint8_t dev_spec;
	uint8_t byte5;
#define	SMPH_LONGLBA		0x01
	uint8_t reserved;
	uint8_t blk_desc_len[2];
};

struct scsi_general_block_descriptor {
	uint8_t density;
	uint8_t nblocks[3];
	uint8_t reserved;
	uint8_t blklen[3];
};

struct scsi_da_block_descriptor {
	uint8_t nblocks[4];
	uint8_t density;
	uint8_t blklen[3];
};

struct scsi_longlba_block_descriptor {
	uint8_t nblocks[8];
	uint8_t density;
	uint8_t reserved[3];
	uint8_t blklen[4];
};

/*
 * Header common to all mode parameter pages.
 */
struct scsi_mode_page_header {
	uint8_t pg_code;
#define	PGCODE_MASK	0x3f		/* page code mask */
#define	PGCODE_PS	0x80		/* page is saveable */
	uint8_t pg_length;		/* page length (not including header) */
};

/*
 * Control mode page
 */
#define	SCSI_CONTROL_MODE_PAGE		0x0a
struct scsi_control_mode_page {
	uint8_t pg_code;		/* 0x0a */
	uint8_t pg_length;		/* 0x0a */
	uint8_t byte3;
#define	SCMP_RLEC		0x01	/* report log exception condition */
#define	SCMP_GLTSD		0x02	/* global logging target save disable */
#define	SCMP_TST_mask		0x7	/* task set type */
#define	SCMP_TST_shift		5
#define	SCMP_TST_ALL_INIT	0	/* per LU for all initiators */
#define	SCMP_TST_PER_INIT	1	/* per initiator per LU */
	uint8_t queue_params;
#define	SCMP_DQue		0x01	/* disable queueing */
#define	SCMP_QErr_mask		0x3	/* queue error management */
#define	SCMP_QErr_shift		1
#define	SCMP_QAM_mask		0xf	/* queue algorithm modifier */
#define	SCMP_QAM_shift		4
#define	SCMP_QAM_RESTRICTED	0x0	/* restricted reordering allowed */
#define	SCMP_QAM_UNRESTRICTED	0x1	/* unrestricted reordering allowed */
			/*	0x2 - 0x7	Reserved */
			/*	0x8 - 0xf	Vendor-specific */
	uint8_t byte5;
#define	SCMP_EAERP		0x01
#define	SCMP_UAAERP		0x02
#define	SCMP_RAERP		0x04
#define	SCMP_SWP		0x08
#define	SCMP_RAC		0x40
#define	SCMP_TAS		0x80
	uint8_t byte6;
#define	SCMP_AM_mask		0x7	/* autload mode */
#define	SCMP_AM_FULL		0
#define	SCMP_AM_AUXMEM		1
#define	SCMP_AM_NOLOAD		2
	uint8_t rahp[2];		/* ready aer holdoff period */
	uint8_t btp[2];			/* busy timeout period */
	uint8_t estct[2];		/* extended self-test completion time */
};

/*
 * Disconnect-reconnect page
 */
#define	SCSI_DISCONNECT_RECONNECT_PAGE	0x02
struct scsi_disconnect_reconnect_page {
	uint8_t pg_code;		/* 0x02 */
	uint8_t pg_length;		/* 0x0e */
	uint8_t buffer_full_ratio;
	uint8_t buffer_empty_ratio;
	uint8_t bus_inactivity_limit[2];
	uint8_t disconnect_time_limit[2];
	uint8_t connect_time_limit[2];
	uint8_t maximum_burst_size[2];
	uint8_t flags;
#define	SDRP_DTDC_mask		0x7	/* data transfer disconnect control */
#define	SDRP_DImm		0x08
#define	SDRP_FA_mask		0x7
#define	SDRP_FA_shift		4
#define	SDRP_EMDP		0x80
	uint8_t reserved;
	uint8_t first_burst_size[2];
};

/*
 * Informational exceptions control page
 */
#define	SCSI_INFORMATIONAL_EXCEPTIONS_CONTROL_PAGE 0x1c
struct scsi_informational_exceptions_control_page {
	uint8_t pg_code;		/* 0x1c */
	uint8_t pg_length;		/* 0x0a */
	uint8_t byte3;
#define	SIECP_LogErr		0x01
#define	SIECP_TEST		0x04
#define	SIECP_DExcpt		0x08
#define	SIECP_EWasc		0x10
#define	SIECP_EBF		0x20
#define	SIECP_PERF		0x80
	uint8_t byte4;
#define	SIECP_MRIE_mask			0xf	/* method of reporting
						   informational exceptions */
#define	SIECP_MRIE_NO_REPORTING		0x00
#define	SIECP_MRIE_ASYNC_EVENT		0x01
#define	SIECP_MRIE_UNIT_ATN		0x02
#define	SIECP_MRIE_COND_RECOV_ERR	0x03
#define	SIECP_MRIE_UNCOND_RECOV_ERR	0x04
#define	SIECP_MRIE_NO_SENSE		0x05
#define	SIECP_MRIE_ON_REQUEST		0x06
				/*	0x07 - 0x0b reserved */
				/*	0x0c - 0x0f Vendor-specific */
	uint8_t interval_timer[2];
	uint8_t report_count[2];
};

/*
 * Power condition page
 */
#define	SCSI_POWER_CONDITION_PAGE	0x1a
struct scsi_power_condition_page {
	uint8_t pg_code;		/* 0x1a */
	uint8_t pg_length;		/* 0x0a */
	uint8_t reserved;
	uint8_t byte4;
#define	SPCP_STANDBY		0x01
#define	SPCP_IDLE		0x02
	uint8_t idle_timer[2];		/* 100ms increments */
	uint8_t standby_timer[2];	/* 100ms increments */
};

/*
 * Protocol specific LUN page
 */
#define	SCSI_PROTOCOL_SPECIFIC_LUN_PAGE	0x18
struct scsi_protocol_specific_lun_page {
	uint8_t pg_code;	/* 0x18 */
	uint8_t pg_length;	/* variable */
	uint8_t byte3;
#define	SPSLP_PROTOCOL_mask	0xf
#define	SPSLP_PROTOCOL_FCP	0x00	/* Fibre Channel */
#define	SPSLP_PROTOCOL_SPI	0x01	/* parallel SCSI */
#define	SPSLP_PROTOCOL_SSA	0x02	/* SSA-S2P or SSA-S3P */
#define	SPSLP_PROTOCOL_SBP2	0x03	/* IEEE 1394 */
#define	SPSLP_PROTOCOL_SRP	0x04	/* SCSI RDMA */
#define	SPSLP_PROTOCOL_ISCSI	0x05	/* iSCSI */
	/* protocol specific mode parameters follow */
};

/*
 * Protocol specific port page
 */
#define	SCSI_PROTOCOL_SPECIFIC_PORT_PAGE 0x19
struct scsi_protocol_specific_port_page {
	uint8_t pg_code;	/* 0x18 */
	uint8_t pg_length;	/* variable */
	uint8_t byte3;		/* see SCSI PROTOCOL SPECIFIC LUN PAGE */
	/* protocol specific mode parameters follow */
};

/*
 * PERSISTENT RESERVE IN
 */

/*
 * PERSISTENT RESERVE OUT
 */

/*
 * PREVENT ALLOW MEDIUM REMOVAL
 */

#define	SCSI_PREVENT_ALLOW_MEDIUM_REMOVAL	0x1e
struct scsi_prevent_allow_medium_removal {
	uint8_t opcode;
	uint8_t byte2;
	uint8_t reserved[2];
	uint8_t how;
#define	SPAMR_ALLOW		0x00
#define	SPAMR_PREVENT_DT	0x01
#define	SPAMR_PREVENT_MC	0x02
#define	SPAMR_PREVENT_ALL	0x03
	uint8_t control;
};

/*
 * READ BUFFER
 */

/*
 * RECEIVE COPY RESULTS
 */

/*
 * RECEIVE DIAGNOSTIC RESULTS
 */

/*
 * RESERVE / RELEASE
 */

#define	SCSI_RESERVE_6			0x16
#define	SCSI_RELEASE_6			0x17
struct scsi_reserve_release_6 {
	uint8_t opcode;
	uint8_t byte2;
	uint8_t obsolete;
	uint8_t reserved[2];
	uint8_t control;
};

#define	SCSI_RESERVE_10			0x56
#define	SCSI_RELEASE_10			0x57
struct scsi_reserve_release_10 {
	uint8_t opcode;
	uint8_t byte2;
#define	SR_LongID		0x02
#define	SR_3rdPty		0x10
	uint8_t obsolete;
	uint8_t thirdpartyid;
	uint8_t reserved[3];
	uint8_t paramlen[2];
	uint8_t control;
};

struct scsi_reserve_release_10_idparam {
	uint8_t thirdpartyid[8];
};

/*
 * REPORT DEVICE IDENTIFIER
 */

/*
 * REPORT LUNS
 */
#define SCSI_REPORT_LUNS		0xa0

struct scsi_report_luns {
	uint8_t opcode;
	uint8_t reserved1;
	uint8_t selectreport;
#define SELECTREPORT_NORMAL		0x00
#define SELECTREPORT_WELLKNOWN		0x01
#define SELECTREPORT_ALL		0x02
	uint8_t reserved3[3];
	uint8_t alloclen[4];
	uint8_t reserved10;
	uint8_t control;
};

struct scsi_report_luns_header {
	uint8_t	length[4];		/* in bytes, not including header */
	uint8_t _res4[4];
					/* followed by array of: */
};

struct scsi_report_luns_lun {
	uint8_t lun[8];
};

/*
 * MAINTENANCE_IN[REPORT SUPPORTED OPERATION CODES]
 */
#define SCSI_MAINTENANCE_IN		0xA3

struct scsi_repsuppopcode {
	u_int8_t opcode;
	u_int8_t svcaction;
#define RSOC_REPORT_SUPPORTED_OPCODES	0x0C

	u_int8_t repoption;
#define RSOC_ALL           0x00 /* report all */
#define RSOC_ONE           0x01 /* report one */
#define RSOC_ONESACD       0x02 /* report one or CHECK CONDITION */
#define RSOC_ONESA         0x03 /* report one mark presense in data */
#define RSOC_RCTD          0x80 /* report timeouts */

	u_int8_t reqopcode;
	u_int8_t reqsvcaction[2];
	u_int8_t alloclen[4];
	u_int8_t _res0;
	u_int8_t control;
};

struct scsi_repsupopcode_all_commands_descriptor {
        u_int8_t opcode;
        u_int8_t _res0;
        u_int8_t serviceaction[2];
        u_int8_t _res1;
        u_int8_t flags;
#define RSOC_ACD_CTDP         0x02    /* timeouts present */
#define RSOC_ACD_SERVACTV     0x01    /* service action valid */
        u_int8_t cdblen[2];
};

struct scsi_repsupopcode_one_command_descriptor {
        u_int8_t _res0;
        u_int8_t support;
#define RSOC_OCD_CTDP              0x80 /* timeouts present */
#define RSOC_OCD_SUP_NOT_AVAIL     0x00 /* not available */
#define RSOC_OCD_SUP_NOT_SUPP      0x01 /* not supported */
#define RSOC_OCD_SUP_SUPP_STD      0x03 /* supported - standard */
#define RSOC_OCD_SUP_SUPP_VENDOR   0x05 /* supported - vendor */
#define RSOC_OCD_SUP               0x07 /* mask for support field */

        u_int8_t cdblen[2];
        /*
	 * u_int8_t usage[0...]- cdblen bytes
	 * usage data
	 */
	/*
	 * scsi_repsupopcode_timeouts_descriptor
	 * if  RSOC_OCD_CTDP is set
	 */
};

struct scsi_repsupopcode_timeouts_descriptor {
        u_int8_t descriptor_length[2];
        u_int8_t _res0;
        u_int8_t cmd_specific;
        u_int8_t nom_process_timeout[4];
        u_int8_t cmd_process_timeout[4];
};

/*
 * REQUEST SENSE
 */

#define	SCSI_REQUEST_SENSE		0x03
struct scsi_request_sense {
	uint8_t opcode;
	uint8_t byte2;
	uint8_t reserved[2];
	uint8_t length;
	uint8_t control;
};

struct scsi_sense_data {
/* 1*/	uint8_t response_code;
#define	SSD_RCODE(x)		((x) & 0x7f)
#define	SSD_RCODE_CURRENT	0x70
#define	SSD_RCODE_DEFERRED	0x71
#define	SSD_RCODE_VALID		0x80
/* 2*/	uint8_t segment;	/* obsolete */
/* 3*/	uint8_t flags;
#define	SSD_SENSE_KEY(x)	((x) & 0x0f)
#define	SSD_ILI			0x20
#define	SSD_EOM			0x40
#define	SSD_FILEMARK		0x80
/* 7*/	uint8_t info[4];
/* 8*/	uint8_t extra_len;		/* Additional sense length */
/*12*/	uint8_t csi[4];			/* Command-specific information */
/*13*/	uint8_t asc;			/* Additional sense code */
/*14*/	uint8_t ascq;			/* Additional sense code qualifier */
/*15*/	uint8_t fru;			/* Field replaceable unit code */
	union {
		uint8_t sks_bytes[3];

		/* ILLEGAL REQUEST */
		struct {
			uint8_t byte0;
#define	SSD_SKS_FP_BIT(x)	((x) & 0x7)
#define	SSD_SKS_FP_BPV		0x08
#define	SSK_SKS_FP_CD		0x40	/* 1=command, 0=data */
			uint8_t val[2];
		} field_pointer;

		/* RECOVERED ERROR, HARDWARE ERROR, MEDIUM ERROR */
		struct {
			uint8_t byte0;
			uint8_t val[2];
		} actual_retry_count;

		/* NOT READY, NO SENSE */
		struct {
			uint8_t byte0;
			uint8_t val[2];
		} progress_indication;

		/* COPY ABORTED */
		struct {
			uint8_t byte0;
#define	SSD_SKS_SP_BIT(x)	((x) & 0x7)
#define	SSD_SKS_SP_BPV		0x08
#define	SSD_SKS_SP_SD		0x20	/* 0=param list, 1=segment desc */
			uint8_t val[2];
		} segment_pointer;
/*18*/	} sks;				/* Sense-key specific */
#define	SSD_SKSV		0x80	/* byte0 of sks field */
/*32*/	uint8_t extra_bytes[14];	/* really variable length */
};

/*
 * Sense bytes described by the extra_len field start at csi[], and can
 * only continue up to the end of the 32-byte sense structure that we
 * have defined (which might be too short for some cases).
 */
#define	SSD_ADD_BYTES_LIM(sp)						\
	((((int)(sp)->extra_len) < (int)sizeof(struct scsi_sense_data) - 8) ? \
	 (sp)->extra_len : sizeof(struct scsi_sense_data) - 8)

#define	SKEY_NO_SENSE		0x00
#define	SKEY_RECOVERED_ERROR	0x01
#define	SKEY_NOT_READY		0x02
#define	SKEY_MEDIUM_ERROR	0x03
#define	SKEY_HARDWARE_ERROR	0x04
#define	SKEY_ILLEGAL_REQUEST	0x05
#define	SKEY_UNIT_ATTENTION	0x06
#define	SKEY_DATA_PROTECT	0x07
#define	SKEY_BLANK_CHECK	0x08
#define	SKEY_VENDOR_SPECIFIC	0x09
#define	SKEY_COPY_ABORTED	0x0a
#define	SKEY_ABORTED_COMMAND	0x0b
#define	SKEY_EQUAL		0x0c	/* obsolete */
#define	SKEY_VOLUME_OVERFLOW	0x0d
#define	SKEY_MISCOMPARE		0x0e
			/*	0x0f	reserved */

/* XXX This is not described in SPC-2. */
struct scsi_sense_data_unextended {
	uint8_t response_code;
	uint8_t block[3];
};

/*
 * SEND DIAGNOSTIC
 */

#define	SCSI_SEND_DIAGNOSTIC		0x1d
struct scsi_send_diagnostic {
	uint8_t opcode;
	uint8_t byte2;
#define	SSD_UnitOffL		0x01
#define	SSD_DevOffL		0x02
#define	SSD_SelfTest		0x04	/* standard self-test */
#define	SSD_PF			0x10	/* results in page format */
#define	SSD_CODE(x)		((x) << 5)
	/*
	 * Codes:
	 *
	 *	0	This value shall be used when the SelfTest bit is
	 *		set to one or if the SEND DIAGNOSTIC command is not
	 *		invoking one of the other self-test functions such
	 *		as enclosure services or the Translate Address page.
	 *
	 *	1	Background short self-test.  Parameter length is 0.
	 *
	 *	2	Background extended self-test.  Parameter length is 0.
	 *
	 *	4	Abort background self-test.  Parameter length is 0.
	 *
	 *	5	Foreground short self-test.  Parameter length is 0.
	 *
	 *	6	Foreground extended self-test.  Parameter length is 0.
	 */
	uint8_t reserved;
	uint8_t paramlen[2];
	uint8_t control;
};

/*
 * SET DEVICE IDENTIFIER
 */

/*
 * TEST UNIT READY
 */

#define	SCSI_TEST_UNIT_READY		0x00
struct scsi_test_unit_ready {
	uint8_t opcode;
	uint8_t byte2;
	uint8_t reserved[3];
	uint8_t control;
};

/*
 * WRITE BUFFER
 */

#endif /* _DEV_SCSIPI_SCSI_SPC_H_ */