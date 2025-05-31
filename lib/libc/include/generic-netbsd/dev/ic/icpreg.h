/*	$NetBSD: icpreg.h,v 1.7 2008/09/08 23:36:54 gmcgarry Exp $	*/

/*-
 * Copyright (c) 2002 The NetBSD Foundation, Inc.
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
 * Copyright (c) 1999, 2000 Niklas Hallqvist.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Niklas Hallqvist.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * from OpenBSD: gdtreg.h,v 1.1 2000/02/07 00:33:03 niklas Exp
 */

#ifndef _IC_ICPREG_H_
#define _IC_ICPREG_H_

#define ICP_MAXBUS		6	/* XXX Why not 5? */
#define ICP_MAX_LDRIVES		255	/* max logical drive count */
#define ICP_MAX_HDRIVES		100	/* max host drive count */
#define ICP_MAXID_FC		127	/* Fibre-channel maximum ID */
#define ICP_MAXOFFSETS		128
#define ICP_MAXSG		17	/* Max. s/g elements; actually 128 */
#define ICP_PROTOCOL_VERSION	1
#define ICP_LINUX_OS		8	/* Used for cache optimization */
#define ICP_SCATTER_GATHER	1	/* s/g feature */
#define ICP_SECS32		0x1f	/* round capacity */
#define ICP_LOCALBOARD		0	/* Board node always 0 */
#define ICP_MAX_CMDS		124
#define ICP_SECTOR_SIZE		0x200	/* Always 512 bytes for cache devs */
#define	ICP_MAX_EVENTS		0x100	/* event buffer */

/* DPMEM constants */
#define ICP_MPR_MAGIC		0xc0ffee11
#define ICP_IC_HEADER_BYTES	48
#define ICP_IC_QUEUE_BYTES	4

/* Cache/raw service commands */
#define ICP_INIT	0		/* service initialization */
#define ICP_READ	1		/* read command */
#define ICP_WRITE	2		/* write command */
#define ICP_INFO	3		/* information about devices */
#define ICP_FLUSH	4		/* flush dirty cache buffers */
#define ICP_IOCTL	5		/* ioctl command */
#define ICP_DEVTYPE	9		/* additional information */
#define ICP_MOUNT	10		/* mount cache device */
#define ICP_UNMOUNT	11		/* unmount cache device */
#define ICP_SET_FEAT	12		/* set features (scatter/gather) */
#define ICP_GET_FEAT	13		/* get features */
#define ICP_WRITE_THR	16		/* write through */
#define ICP_READ_THR	17		/* read through */
#define ICP_EXT_INFO	18		/* extended info */
#define ICP_RESET	19		/* controller reset */
#define ICP_FREEZE_IO	25		/* freeze all IOs */
#define ICP_UNFREEZE_IO	26		/* unfreeze all IOs */

/* Additional raw service commands */
#define ICP_RESERVE	14		/* reserve device to raw service */
#define ICP_RELEASE	15		/* release device */
#define ICP_RESERVE_ALL 16		/* reserve all devices */
#define ICP_RELEASE_ALL 17		/* release all devices */
#define ICP_RESET_BUS	18		/* reset bus */
#define ICP_SCAN_START	19		/* start device scan */
#define ICP_SCAN_END	20		/* stop device scan */

/* IOCTL command defines */
#define ICP_SCSI_DR_INFO	0x00	/* SCSI drive info */
#define ICP_SCSI_CHAN_CNT	0x05	/* SCSI channel count */
#define ICP_SCSI_DR_LIST	0x06	/* SCSI drive list */
#define ICP_SCSI_DEF_CNT	0x15	/* grown/primary defects */
#define ICP_DSK_STATISTICS	0x4b	/* SCSI disk statistics */
#define ICP_IOCHAN_DESC		0x5d	/* description of IO channel */
#define ICP_IOCHAN_RAW_DESC	0x5e	/* description of raw IO channel */

#define ICP_L_CTRL_PATTERN	0x20000000	/* SCSI IOCTL mask */
#define ICP_ARRAY_INFO		0x12		/* array drive info */
#define ICP_ARRAY_DRV_LIST	0x0f		/* array drive list */
#define ICP_LA_CTRL_PATTERN	0x10000000	/* array IOCTL mask */
#define ICP_CACHE_DRV_CNT	0x01		/* cache drive count */
#define ICP_CACHE_DRV_LIST	0x02		/* cache drive list */
#define ICP_CACHE_INFO		0x04		/* cache info */
#define ICP_CACHE_CONFIG	0x05		/* cache configuration */
#define ICP_CACHE_DRV_INFO	0x07		/* cache drive info */
#define ICP_BOARD_FEATURES	0x15		/* controller features */
#define ICP_BOARD_INFO		0x28		/* controller info */
#define ICP_HOST_GET		0x10001		/* get host drive list */
#define ICP_IO_CHANNEL		0x20000		/* default IO channel */
#define ICP_INVALID_CHANNEL	0xffff		/* invalid channel */

/* Service errors */
#define	ICP_S_MSG_REQUEST	0	/* screen service: async evt message */
#define ICP_S_OK		1	/* no error */
#define ICP_S_BSY		7	/* controller busy */
#define ICP_S_RAW_SCSI		12	/* raw service: target error */
#define ICP_S_RAW_ILL		0xff	/* raw service: illegal */
#define ICP_S_NO_STATUS		0x1000	/* got no status (driver-generated) */

/* Controller services */
#define ICP_SCSIRAWSERVICE	3
#define ICP_CACHESERVICE	9
#define ICP_SCREENSERVICE	11

/* Data direction raw service. */
#define	ICP_DATA_IN		0x01000000
#define	ICP_DATA_OUT		0x00000000

/* Command queue entries */
#define ICP_OFFSET	0x00	/* u_int16_t, command offset in the DP RAM */
#define ICP_SERV_ID	0x02	/* u_int16_t, service */
#define ICP_COMM_Q_SZ	0x04

/* Interface area */
#define ICP_S_CMD_INDX	0x00	/* u_int8_t, special command */
#define	ICP_S_STATUS	0x01	/* volatile u_int8_t, status special command */
#define ICP_S_INFO	0x04	/* u_int32_t [4], add. info special command */
#define ICP_SEMA0	0x14	/* volatile u_int8_t, command semaphore */
#define ICP_CMD_INDEX	0x18	/* u_int8_t, command number */
#define ICP_STATUS	0x1c	/* volatile u_int16_t, command status */
#define ICP_SERVICE	0x1e	/* u_int16_t, service (for asynch. events) */
#define ICP_DPR_INFO	0x20	/* u_int32_t [2], additional info */
#define ICP_COMM_QUEUE	0x28	/* command queue */
#define ICP_DPR_CMD	(0x30 + ICP_MAXOFFSETS * ICP_COMM_Q_SZ)
				/* u_int8_t [], commands */
#define ICP_DPR_IF_SZ	ICP_DPR_CMD

/* Get cache info */
#define ICP_CINFO_CPAR		0x00
#define ICP_CINFO_CSTAT		0x0c

/* Other defines */
#define ICP_ASYNCINDEX	0	/* command index asynchronous event */
#define ICP_SPEZINDEX	1	/* command index unknown service */

/* I/O channel header */
struct icp_ioc_version {
	u_int32_t	iv_version;	/* version (~0: newest) */
	u_int8_t	iv_listents;	/* list entry count */
	u_int8_t	iv_firstchan;	/* first channel number */
	u_int8_t	iv_lastchan;	/* last channel number */
	u_int8_t	iv_chancount;	/* channel count */
	u_int32_t	iv_listoffset;	/* offset of list[0] */
} __packed;

#define	ICP_IOC_NEWEST	0xffffffff

/* Get I/O channel description */
struct icp_ioc {
	u_int32_t	io_addr;	/* channel address */
	u_int8_t	io_type;	/* type (SCSI/FCAL) */
	u_int8_t	io_localno;	/* local number */
	u_int16_t	io_features;	/* channel features */
} __packed;

/* Get raw I/O channel description */
struct icp_rawioc {
	u_int8_t	ri_procid;	/* processor ID */
	u_int8_t	ri_defect;	/* defect? */
	u_int16_t	ri_padding;
} __packed;

/* Get SCSI channel count */
struct icp_getch {
	u_int32_t	gc_channo;	/* channel number */
	u_int32_t	gc_drivecnt;	/* drive count */
	u_int8_t	gc_scsiid;	/* SCSI initiator ID */
	u_int8_t	gc_scsistate;	/* SCSI processor state */
} __packed;

/* Cache info/config IOCTL structures */
struct icp_cpar {
	u_int32_t	cp_version;	/* firmware version */
	u_int16_t	cp_state;	/* cache state (on/off) */
	u_int16_t	cp_strategy;	/* cache strategy */
	u_int16_t	cp_write_back;	/* write back (on/off) */
	u_int16_t	cp_block_size;	/* cache block size */
} __packed;

struct icp_cstat {
	u_int32_t	cs_size;	/* cache size */
	u_int32_t	cs_readcnt;	/* read counter */
	u_int32_t	cs_writecnt;	/* write counter */
	u_int32_t	cs_trhits;	/* track hits */
	u_int32_t	cs_sechits;	/* sector hits */
	u_int32_t	cs_secmiss;	/* sector misses */
} __packed;

/* Board information. */
struct icp_binfo {
	u_int32_t	bi_ser_no;		/* serial number */
	u_int8_t	bi_oem_id[2];		/* OEM ID */
	u_int16_t	bi_ep_flags;		/* eprom flags */
	u_int32_t	bi_proc_id;		/* processor ID */
	u_int32_t	bi_memsize;		/* memory size (bytes) */
	u_int8_t	bi_mem_banks;		/* memory banks */
	u_int8_t	bi_chan_type;		/* channel type */
	u_int8_t	bi_chan_count;		/* channel count */
	u_int8_t	bi_rdongle_pres;	/* dongle present */
	u_int32_t	bi_epr_fw_ver;		/* (eprom) firmware ver */
	u_int32_t	bi_upd_fw_ver;		/* (update) firmware ver */
	u_int32_t	bi_upd_revision;	/* update revision */
	char		bi_type_string[16];	/* char controller name */
	char		bi_raid_string[16];	/* char RAID firmware name */
	u_int8_t	bi_update_pres;		/* update present? */
	u_int8_t	bi_xor_pres;		/* XOR engine present */
	u_int8_t	bi_prom_type;		/* ROM type (eprom/flash) */
	u_int8_t	bi_prom_count;		/* number of ROM devices */
	u_int32_t	bi_dup_pres;		/* duplexing module pres? */
	u_int32_t	bi_chan_pres;		/* # of exp. channels */
	u_int32_t	bi_mem_pres;		/* memory expansion inst? */
	u_int8_t	bi_ft_bus_system;	/* fault bus supported? */
	u_int8_t	bi_subtype_valid;	/* board_subtype valid */
	u_int8_t	bi_board_subtype;	/* subtype/hardware level */
	u_int8_t	bi_rampar_pres;		/* RAM parity check hw? */
} __packed;

/* Board features. */
struct icp_bfeat {
	u_int8_t	bf_chaining;	/* chaining supported */
	u_int8_t	bf_striping;	/* striping (RAID-0) supported */
	u_int8_t	bf_mirroring;	/* mirroring (RAID-1) supported */
	u_int8_t	bf_raid;	/* RAID-4/5/10 supported */
} __packed;

/* Cache drive information. */
struct icp_cdevinfo {
	char		cd_name[8];
	u_int32_t	cd_devtype;
	u_int32_t	cd_ldcnt;
	u_int32_t	cd_last_error;
	u_int8_t	cd_initialized;
	u_int8_t	cd_removable;
	u_int8_t	cd_write_protected;
	u_int8_t	cd_flags;
	u_int32_t	ld_blkcnt;
	u_int32_t	ld_blksize;
	u_int32_t	ld_dcnt;
	u_int32_t	ld_slave;
	u_int32_t	ld_dtype;
	u_int32_t	ld_last_error;
	char		ld_name[8];
	u_int8_t	ld_error;
} __packed;

struct icp_sg {
	u_int32_t	sg_addr;
	u_int32_t	sg_len;
} __packed;

struct icp_cachecmd {
	u_int16_t	cc_deviceno;
	u_int32_t	cc_blockno;
	u_int32_t	cc_blockcnt;
	u_int32_t	cc_addr;		/* ~0 == s/g */
	u_int32_t	cc_nsgent;
	struct icp_sg	cc_sg[ICP_MAXSG];
} __packed;

struct icp_ioctlcmd {
	u_int16_t	ic_bufsize;
	u_int32_t	ic_subfunc;
	u_int32_t	ic_channel;
	u_int32_t	ic_addr;
} __packed;

struct icp_screencmd {
	u_int32_t	sc_msghandle;
	u_int32_t	sc_msgaddr;
} __packed;

struct icp_rawcmd {
	u_int16_t	rc_padding0;		/* unused */
	u_int32_t	rc_direction;		/* data direction */
	u_int32_t	rc_mdisc_time;		/* disc. time (0: none) */
	u_int32_t	rc_mcon_time;		/* conn. time (0: none) */
	u_int32_t	rc_sdata;		/* dest address */
	u_int32_t	rc_sdlen;		/* data length */
	u_int32_t	rc_clen;		/* CDB length */
	u_int8_t	rc_cdb[12];		/* SCSI CDB */
	u_int8_t	rc_target;		/* target ID */
	u_int8_t	rc_lun;			/* LUN */
	u_int8_t	rc_bus;			/* channel */
	u_int8_t	rc_priority;		/* priority; 0 only */
	u_int32_t	rc_sense_len;		/* sense length */
	u_int32_t	rc_sense_addr;		/* sense address */
	u_int32_t	rc_padding1;		/* unused */
	u_int32_t	rc_nsgent;		/* s/g element count */
	struct icp_sg	rc_sg[ICP_MAXSG];	/* s/g list */
} __packed;

struct icp_cmdhdr {
	u_int32_t	cmd_boardnode;		/* always 0 */
	u_int32_t	cmd_cmdindex;		/* command identifier */
	u_int16_t	cmd_opcode;
} __packed;

struct icp_cmd {
	u_int32_t	cmd_boardnode;		/* always 0 */
	u_int32_t	cmd_cmdindex;		/* command identifier */
	u_int16_t	cmd_opcode;

	union {
		struct icp_rawcmd	rc;
		struct icp_screencmd	sc;
		struct icp_ioctlcmd	ic;
		struct icp_cachecmd	cc;
	} cmd_packet;
} __packed;

#endif	/* !_IC_ICPREG_H_ */