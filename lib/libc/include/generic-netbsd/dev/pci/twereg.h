/*	$NetBSD: twereg.h,v 1.16 2018/11/08 06:34:40 msaitoh Exp $	*/

/*-
 * Copyright (c) 2000 The NetBSD Foundation, Inc.
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

/*-
 * Copyright (c) 2000 Michael Smith
 * Copyright (c) 2000 BSDi
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
 * from FreeBSD: twereg.h,v 1.1 2000/05/24 23:35:23 msmith Exp
 */

#ifndef _PCI_TWEREG_H_
#define	_PCI_TWEREG_H_

/* Board registers. */
#define	TWE_REG_CTL			0x00
#define	TWE_REG_STS			0x04
#define	TWE_REG_CMD_QUEUE		0x08
#define	TWE_REG_RESP_QUEUE		0x0c

/* Control register bit definitions. */
#define	TWE_CTL_CLEAR_HOST_INTR		0x00080000
#define	TWE_CTL_CLEAR_ATTN_INTR		0x00040000
#define	TWE_CTL_MASK_CMD_INTR		0x00020000
#define	TWE_CTL_MASK_RESP_INTR		0x00010000
#define	TWE_CTL_UNMASK_CMD_INTR		0x00008000
#define	TWE_CTL_UNMASK_RESP_INTR	0x00004000
#define	TWE_CTL_CLEAR_ERROR_STS		0x00000200
#define	TWE_CTL_ISSUE_SOFT_RESET	0x00000100
#define	TWE_CTL_ENABLE_INTRS		0x00000080
#define	TWE_CTL_DISABLE_INTRS		0x00000040
#define	TWE_CTL_ISSUE_HOST_INTR		0x00000020
#define	TWE_CTL_CLEAR_PARITY_ERROR	0x00800000
#define	TWE_CTL_CLEAR_PCI_ABORT		0x00100000

/* Status register bit definitions. */
#define	TWE_STS_MAJOR_VERSION_MASK	0xf0000000
#define	TWE_STS_MINOR_VERSION_MASK	0x0f000000
#define	TWE_STS_PCI_PARITY_ERROR	0x00800000
#define	TWE_STS_QUEUE_ERROR		0x00400000
#define	TWE_STS_MICROCONTROLLER_ERROR	0x00200000
#define	TWE_STS_PCI_ABORT		0x00100000
#define	TWE_STS_HOST_INTR		0x00080000
#define	TWE_STS_ATTN_INTR		0x00040000
#define	TWE_STS_CMD_INTR		0x00020000
#define	TWE_STS_RESP_INTR		0x00010000
#define	TWE_STS_CMD_QUEUE_FULL		0x00008000
#define	TWE_STS_RESP_QUEUE_EMPTY	0x00004000
#define	TWE_STS_MICROCONTROLLER_READY	0x00002000
#define	TWE_STS_CMD_QUEUE_EMPTY		0x00001000

#define	TWE_STS_ALL_INTRS		0x000f0000
#define	TWE_STS_CLEARABLE_BITS		0x00d00000
#define	TWE_STS_EXPECTED_BITS		0x00002000
#define	TWE_STS_UNEXPECTED_BITS		0x00f80000

/* Command packet opcodes. */
#define TWE_OP_NOP			0x00
#define TWE_OP_INIT_CONNECTION		0x01
#define TWE_OP_READ			0x02
#define TWE_OP_WRITE			0x03
#define TWE_OP_READVERIFY		0x04
#define TWE_OP_VERIFY			0x05
#define TWE_OP_PROBE			0x06
#define TWE_OP_PROBEUNIT		0x07
#define TWE_OP_ZEROUNIT			0x08
#define TWE_OP_REPLACEUNIT		0x09
#define TWE_OP_HOTSWAP			0x0a
#define TWE_OP_SETATAFEATURE		0x0c
#define TWE_OP_FLUSH			0x0e
#define TWE_OP_ABORT			0x0f
#define TWE_OP_CHECKSTATUS		0x10
#define	TWE_OP_ATA_PASSTHROUGH		0x11
#define TWE_OP_GET_PARAM		0x12
#define TWE_OP_SET_PARAM		0x13
#define TWE_OP_CREATEUNIT		0x14
#define TWE_OP_DELETEUNIT		0x15
#define TWE_OP_REBUILDUNIT		0x17
#define TWE_OP_SECTOR_INFO		0x1a
#define TWE_OP_AEN_LISTEN		0x1c
#define TWE_OP_CMD_PACKET		0x1d
#define	TWE_OP_CMD_WITH_DATA		0x1f

/* Response queue entries.  Masking and shifting yields request ID. */
#define	TWE_RESP_MASK			0x00000ff0
#define	TWE_RESP_SHIFT			4

/* Miscellenous constants. */
#define	TWE_ALIGNMENT			512
#define	TWE_MAX_UNITS			16
#define	TWE_INIT_CMD_PACKET_SIZE	0x3
#define	TWE_SG_SIZE			62
#define	TWE_MAX_CMDS			255
#define	TWE_Q_START			0
#define	TWE_UNIT_INFORMATION_TABLE_BASE	0x300
#define	TWE_IOCTL			0x80
#define	TWE_SECTOR_SIZE			512

/* Scatter/gather block. */
struct twe_sgb {
	u_int32_t	tsg_address;
	u_int32_t	tsg_length;
} __packed;

/*
 * Command block.  This is 512 (really 508) bytes in size, and must be
 * aligned on a 512 byte boundary.
 */
struct twe_cmd {
	u_int8_t	tc_opcode;	/* high 3 bits is S/G list offset */
	u_int8_t	tc_size;
	u_int8_t	tc_cmdid;
	u_int8_t	tc_unit;	/* high nybble is host ID */
	u_int8_t	tc_status;
	u_int8_t	tc_flags;
	u_int16_t	tc_count;	/* block & param count, msg credits */
	union {
		struct {
			u_int32_t	lba;
			struct	twe_sgb sgl[TWE_SG_SIZE];
		} io __packed;
		struct {
			struct	twe_sgb sgl[TWE_SG_SIZE];
		} param;
		struct {
			u_int32_t	response_queue_pointer;
		} init_connection  __packed;
	} tc_args;
	int32_t		tc_pad;
} __packed;

/* Get/set parameter block. */
struct twe_param {
	u_int16_t	tp_table_id;
	u_int8_t	tp_param_id;
	u_int8_t	tp_param_size;
	u_int8_t	tp_data[1];
} __packed;

/*
 * From 3ware's documentation:
 *
 *   All parameters maintained by the controller are grouped into related
 *   tables.  Tables are accessed indirectly via get and set parameter
 *   commands.  To access a specific parameter in a table, the table ID and
 *   parameter index are used to uniquely identify a parameter.  Table
 *   0xffff is the directory table and provides a list of the table IDs and
 *   sizes of all other tables.  Index zero in each table specifies the
 *   entire table, and index one specifies the size of the table.  An entire
 *   table can be read or set by using index zero.
 */

#define TWE_PARAM_PARAM_ALL	0
#define TWE_PARAM_PARAM_SIZE	1

#define TWE_PARAM_DIRECTORY			0xffff	/* size is 4 * number of tables */
#define TWE_PARAM_DIRECTORY_TABLES		2	/* 16 bits * number of tables */
#define TWE_PARAM_DIRECTORY_SIZES		3	/* 16 bits * number of tables */

#define TWE_PARAM_DRIVESUMMARY			0x0002
#define TWE_PARAM_DRIVESUMMARY_Num		2	/* number of physical drives [2] */
#define TWE_PARAM_DRIVESUMMARY_Status		3	/* array giving drive status per aport */
#define TWE_PARAM_DRIVESTATUS_Missing		0x00
#define TWE_PARAM_DRIVESTATUS_NotSupp		0xfe
#define TWE_PARAM_DRIVESTATUS_Present		0xff

#define TWE_PARAM_UNITSUMMARY			0x0003
#define TWE_PARAM_UNITSUMMARY_Num		2	/* number of logical units [2] */
#define TWE_PARAM_UNITSUMMARY_Status		3	/* array giving unit status [16] */
#define TWE_PARAM_UNITSTATUS_Online		(1<<0)
#define TWE_PARAM_UNITSTATUS_Complete		(1<<1)
#define TWE_PARAM_UNITSTATUS_MASK		0xfc
#define TWE_PARAM_UNITSTATUS_Normal		0xfc
#define TWE_PARAM_UNITSTATUS_Initialising	0xf4	/* cannot be incomplete */
#define TWE_PARAM_UNITSTATUS_Degraded		0xec
#define TWE_PARAM_UNITSTATUS_Rebuilding		0xdc	/* cannot be incomplete */
#define TWE_PARAM_UNITSTATUS_Verifying		0xcc	/* cannot be incomplete */
#define TWE_PARAM_UNITSTATUS_Corrupt		0xbc	/* cannot be complete */
#define TWE_PARAM_UNITSTATUS_Missing		0x00	/* cannot be complete or online */

#define TWE_PARAM_DRIVEINFO			0x0200	/* add drive number 0x00-0x0f XXX docco confused 0x0100 vs 0x0200 */
#define TWE_PARAM_DRIVEINFO_Size		2	/* size in blocks [4] */
#define TWE_PARAM_DRIVEINFO_Model		3	/* drive model string [40] */
#define TWE_PARAM_DRIVEINFO_Serial		4	/* drive serial number [20] */
#define TWE_PARAM_DRIVEINFO_PhysCylNum		5	/* physical geometry [2] */
#define TWE_PARAM_DRIVEINFO_PhysHeadNum		6	/* [2] */
#define TWE_PARAM_DRIVEINFO_PhysSectorNum	7	/* [2] */
#define TWE_PARAM_DRIVEINFO_LogCylNum		8	/* logical geometry [2] */
#define TWE_PARAM_DRIVEINFO_LogHeadNum		9	/* [2] */
#define TWE_PARAM_DRIVEINFO_LogSectorNum	10	/* [2] */
#define TWE_PARAM_DRIVEINFO_UnitNum		11	/* unit number this drive is associated with or 0xff [1] */
#define TWE_PARAM_DRIVEINFO_DriveFlags		12	/* N/A [1] */

#define TWE_PARAM_APORTTIMEOUT			0x02c0	/* add (aport_number * 3) to parameter index */
#define TWE_PARAM_APORTTIMEOUT_READ		2	/* read timeouts last 24hrs [2] */
#define TWE_PARAM_APORTTIMEOUT_WRITE		3	/* write timeouts last 24hrs [2] */
#define TWE_PARAM_APORTTIMEOUT_DEGRADE		4	/* degrade threshold [2] */

#define TWE_PARAM_UNITINFO			0x0300	/* add unit number 0x00-0x0f */
#define TWE_PARAM_UNITINFO_Number		2	/* unit number [1] */
#define TWE_PARAM_UNITINFO_Status		3	/* unit status [1] */
#define TWE_PARAM_UNITINFO_Capacity		4	/* unit capacity in blocks [4] */
#define TWE_PARAM_UNITINFO_DescriptorSize	5	/* unit descriptor size + 3 bytes [2] */
#define TWE_PARAM_UNITINFO_Descriptor		6	/* unit descriptor, TWE_UnitDescriptor or TWE_Array_Descriptor */
#define TWE_PARAM_UNITINFO_Flags		7	/* unit flags [1] */
#define TWE_PARAM_UNITFLAGS_WCE			(1<<0)

#define TWE_PARAM_AEN				0x0401
#define TWE_PARAM_AEN_UnitCode			2	/* (unit number << 8) | AEN code [2] */
#define TWE_AEN_QUEUE_EMPTY			0x00
#define TWE_AEN_SOFT_RESET			0x01
#define TWE_AEN_DEGRADED_MIRROR			0x02	/* reports unit */
#define TWE_AEN_CONTROLLER_ERROR		0x03
#define TWE_AEN_REBUILD_FAIL			0x04	/* reports unit */
#define TWE_AEN_REBUILD_DONE			0x05	/* reports unit */
#define TWE_AEN_INCOMP_UNIT			0x06	/* reports unit */
#define TWE_AEN_INIT_DONE			0x07	/* reports unit */
#define TWE_AEN_UNCLEAN_SHUTDOWN		0x08	/* reports unit */
#define TWE_AEN_APORT_TIMEOUT			0x09	/* reports unit, rate limited to 1 per 2^16 errors */
#define TWE_AEN_DRIVE_ERROR			0x0a	/* reports unit */
#define TWE_AEN_REBUILD_STARTED			0x0b	/* reports unit */
#define TWE_AEN_QUEUE_FULL			0xff
#define TWE_AEN_TABLE_UNDEFINED			0x15
#define TWE_AEN_CODE(x)				((x) & 0xff)
#define TWE_AEN_UNIT(x)				((x) >> 8)

#define TWE_PARAM_VERSION			0x0402
#define TWE_PARAM_VERSION_Mon			2	/* monitor version [16] */
#define TWE_PARAM_VERSION_FW			3	/* firmware version [16] */
#define TWE_PARAM_VERSION_BIOS			4	/* BIOSs version [16] */
#define TWE_PARAM_VERSION_PCB			5	/* PCB version [8] */
#define TWE_PARAM_VERSION_ATA			6	/* A-chip version [8] */
#define TWE_PARAM_VERSION_PCI			7	/* P-chip version [8] */
#define TWE_PARAM_VERSION_CtrlModel		8	/* N/A */
#define TWE_PARAM_VERSION_CtrlSerial		9	/* N/A */
#define TWE_PARAM_VERSION_SBufSize		10	/* N/A */
#define TWE_PARAM_VERSION_CompCode		11	/* compatibility code [4] */

#define TWE_PARAM_CONTROLLER			0x0403
#define TWE_PARAM_CONTROLLER_DCBSectors		2	/* # sectors reserved for DCB per drive [2] */
#define TWE_PARAM_CONTROLLER_PortCount		3	/* number of drive ports [1] */

#define TWE_PARAM_FEATURES			0x404
#define TWE_PARAM_FEATURES_DriverShutdown	2	/* set to 1 if driver supports shutdown notification [1] */

#define TWE_PARAM_PROC				0x406
#define TWE_PARAM_PROC_PERCENT			2	/* Per-sub-unit % complete of init/verify/rebuild or 0xff [16] */

struct twe_unit_descriptor {
	u_int8_t	num_subunits;	/* must be zero */
	u_int8_t	configuration;
#define TWE_UD_CONFIG_CBOD	0x0c	/* JBOD with DCB, used for mirrors */
#define TWE_UD_CONFIG_SPARE	0x0d	/* same as CBOD, but firmware will use as spare */
#define TWE_UD_CONFIG_SUBUNIT	0x0e	/* drive is a subunit in an array */
#define TWE_UD_CONFIG_JBOD	0x0f	/* plain drive */
	u_int8_t	phys_drv_num;	/* may be 0xff if port can't be determined at runtime */
	u_int8_t	log_drv_num;	/* must be zero for configuration == 0x0f */
	u_int32_t	start_lba;
	u_int32_t	block_count;	/* actual drive size if configuration == 0x0f, otherwise less DCB size */
} __packed;

struct twe_mirror_descriptor {
	u_int8_t	flag;			/* must be 0xff */
	u_int8_t	res1;
	u_int8_t	mirunit_status[4];	/* bitmap of functional subunits in each mirror */
	u_int8_t	res2[6];
} __packed;

struct twe_array_descriptor {
	u_int8_t	num_subunits;	/* number of subunits, or number of mirror units in RAID10 */
	u_int8_t	configuration;
#define TWE_AD_CONFIG_RAID0	0x00
#define TWE_AD_CONFIG_RAID1	0x01
#define TWE_AD_CONFIG_TwinStor	0x02
#define TWE_AD_CONFIG_RAID5	0x05
#define TWE_AD_CONFIG_RAID10	0x06
	u_int8_t		stripe_size;
#define TWE_AD_STRIPE_4k	0x03
#define TWE_AD_STRIPE_8k	0x04
#define TWE_AD_STRIPE_16k	0x05
#define TWE_AD_STRIPE_32k	0x06
#define TWE_AD_STRIPE_64k	0x07
#define TWE_AD_STRIPE_128k	0x08
#define TWE_AD_STRIPE_256k	0x09
#define TWE_AD_STRIPE_512k	0x0a
#define TWE_AD_STRIPE_1024k	0x0b
	u_int8_t		log_drv_status;	/* bitmap of functional subunits, or mirror units in RAID10 */
	u_int32_t		start_lba;
	u_int32_t		block_count;	/* actual drive size if configuration == 0x0f, otherwise less DCB size */
	struct twe_unit_descriptor	subunit[1];
} __packed;

#endif	/* !_PCI_TWEREG_H_ */