/*	$NetBSD: mlxreg.h,v 1.8 2008/09/08 23:36:54 gmcgarry Exp $	*/

/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
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
 * Copyright (c) 1999 Michael Smith
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
 * from FreeBSD: mlxreg.h,v 1.5.2.2 2000/04/24 19:40:50 msmith Exp
 */

#ifndef _IC_MLXREG_H_
#define	_IC_MLXREG_H_

#define	MLX_SECTOR_SIZE		512

/*
 * Selected command codes.
 */
#define	MLX_CMD_ENQUIRY_OLD	0x05
#define	MLX_CMD_ENQUIRY		0x53
#define	MLX_CMD_ENQUIRY2	0x1c
#define	MLX_CMD_ENQSYSDRIVE	0x19
#define	MLX_CMD_READSG		0xb6
#define	MLX_CMD_WRITESG		0xb7
#define	MLX_CMD_READSG_OLD	0x82
#define	MLX_CMD_WRITESG_OLD	0x83
#define	MLX_CMD_FLUSH		0x0a
#define	MLX_CMD_LOGOP		0x72
#define	MLX_CMD_REBUILDASYNC	0x16
#define	MLX_CMD_CHECKASYNC	0x1e
#define	MLX_CMD_REBUILDSTAT	0x0c
#define	MLX_CMD_STOPCHANNEL	0x13
#define	MLX_CMD_STARTCHANNEL	0x12
#define	MLX_CMD_READ_CONFIG	0x4e
#define	MLX_CMD_WRITE_CONFIG	0x4f
#define	MLX_CMD_READ_DK_CONFIG	0x4a
#define	MLX_CMD_WRITE_DK_CONFIG	0x4b
#define	MLX_CMD_DIRECT_CDB	0x04
#define	MLX_CMD_DEVICE_STATE	0x50
#define	MLX_CMD_READ_CONFIG2	0x3d
#define	MLX_CMD_WRITE_CONFIG2	0x3c

#ifdef _KERNEL

/*
 * Status values.
 */
#define	MLX_STATUS_OK		0x0000
#define	MLX_STATUS_RDWROFFLINE	0x0002	/* read/write claims drive is offline */
#define	MLX_STATUS_WEDGED	0xdeaf	/* controller not listening */
#define	MLX_STATUS_LOST		0xdead	/* never came back */
#define	MLX_STATUS_BUSY		0xbabe	/* command is in controller */

/*
 * V1 (EISA) interface.
 */
#define	MLX_V1REG_IE			0x09
#define	MLX_V1REG_IDB			0x0d
#define	MLX_V1REG_ODB_EN		0x0e
#define	MLX_V1REG_ODB			0x0f
#define	MLX_V1REG_MAILBOX		0x10

#define	MLX_V1_IDB_FULL		0x01	/* mailbox is full */
#define	MLX_V1_IDB_INIT_BUSY	0x02	/* init in progress */

#define	MLX_V1_IDB_SACK		0x02	/* acknowledge status read */
#define	MLX_V1_IDB_RESET	0x10	/* reset controller */

#define	MLX_V1_ODB_SAVAIL	0x01	/* status is available */
#define	MLX_V1_ODB_RESET	0x02	/* reset controller */

#define	MLX_V1_FWERROR_PEND	0x04	/* firmware error pending */

/*
 * V2/V3 interface.
 */
#define	MLX_V3REG_MAILBOX		0x00
#define	MLX_V3REG_STATUS_IDENT		0x0d
#define	MLX_V3REG_STATUS		0x0e
#define	MLX_V3REG_IDB			0x40
#define	MLX_V3REG_ODB			0x41
#define	MLX_V3REG_IE			0x43
#define	MLX_V3REG_FWERROR		0x3f
#define	MLX_V3REG_FWERROR_PARAM1	0x00
#define	MLX_V3REG_FWERROR_PARAM2	0x01

#define	MLX_V3_IDB_FULL		0x01	/* mailbox is full */
#define	MLX_V3_IDB_INIT_BUSY	0x02	/* init in progress */

#define	MLX_V3_IDB_SACK		0x02	/* acknowledge status read */
#define	MLX_V3_IDB_RESET	0x08	/* reset controller */

#define	MLX_V3_ODB_SAVAIL	0x01	/* status is available */

#define	MLX_V3_FWERROR_PEND	0x04	/* firmware error pending */

/*
 * V4 interface.
 */
#define	MLX_V4REG_MAILBOX		0x1000
#define	MLX_V4REG_STATUS_IDENT		0x1018
#define	MLX_V4REG_STATUS		0x101a
#define	MLX_V4REG_IDB			0x0020
#define	MLX_V4REG_ODB			0x002c
#define	MLX_V4REG_IE			0x0034
#define	MLX_V4REG_FWERROR		0x103f
#define	MLX_V4REG_FWERROR_PARAM1	0x1000
#define	MLX_V4REG_FWERROR_PARAM2	0x1001

#define	MLX_V4_IDB_FULL		0x01	/* mailbox is full */
#define	MLX_V4_IDB_INIT_BUSY	0x02	/* initialisation in progress */

#define	MLX_V4_IDB_HWMBOX_CMD	0x01	/* posted hardware mailbox command */
#define	MLX_V4_IDB_SACK		0x02	/* acknowledge status read */
#define	MLX_V4_IDB_MEMMBOX_CMD	0x10	/* posted memory mailbox command */

#define	MLX_V4_ODB_HWSAVAIL	0x01	/* status available for hardware m/b */
#define	MLX_V4_ODB_MEMSAVAIL	0x02	/* status available for memory m/b */

#define	MLX_V4_ODB_HWMBOX_ACK	0x01	/* ack status read from hardware m/b */
#define	MLX_V4_ODB_MEMMBOX_ACK	0x02	/* ack status read from memory m/b */

#define	MLX_V4_IE_MASK		0xfb	/* message unit interrupt mask */
#define	MLX_V4_IE_DISINT	0x04	/* interrupt disable bit */

#define	MLX_V4_FWERROR_PEND	0x04	/* firmware error pending */

/*
 * V5 interface.
 */
#define	MLX_V5REG_MAILBOX		0x50
#define	MLX_V5REG_STATUS_IDENT		0x5d
#define	MLX_V5REG_STATUS		0x5e
#define	MLX_V5REG_IDB			0x60
#define	MLX_V5REG_ODB			0x61
#define	MLX_V5REG_IE			0x34
#define	MLX_V5REG_FWERROR		0x63
#define	MLX_V5REG_FWERROR_PARAM1	0x50
#define	MLX_V5REG_FWERROR_PARAM2	0x51

#define	MLX_V5_IDB_EMPTY	0x01	/* mailbox is empty */
#define	MLX_V5_IDB_INIT_DONE	0x02	/* initialisation has completed */

#define	MLX_V5_IDB_HWMBOX_CMD	0x01	/* posted hardware mailbox command */
#define	MLX_V5_IDB_SACK		0x02	/* acknowledge status read */
#define	MLX_V5_IDB_RESET	0x08	/* reset request */
#define	MLX_V5_IDB_MEMMBOX_CMD	0x10	/* posted memory mailbox command */

#define	MLX_V5_ODB_HWSAVAIL	0x01	/* status available for hardware m/b */
#define	MLX_V5_ODB_MEMSAVAIL	0x02	/* status available for memory m/b */

#define	MLX_V5_ODB_HWMBOX_ACK	0x01	/* ack status read from hardware m/b */
#define	MLX_V5_ODB_MEMMBOX_ACK	0x02	/* ack status read from memory m/b */

#define	MLX_V5_IE_DISINT	0x04	/* interrupt disable bit */

#define	MLX_V5_FWERROR_PEND	0x04	/* firmware error pending */

#endif /* _KERNEL */

/*
 * Scatter-gather list format, type 1, kind 00.
 */
struct mlx_sgentry {
	u_int32_t	sge_addr;
	u_int32_t	sge_count;
} __packed;

/*
 * Command result buffers, as placed in system memory by the controller.
 */
struct mlx_enquiry_old {
	u_int8_t	me_num_sys_drvs;
	u_int8_t	me_res1[3];
	u_int32_t	me_drvsize[8];
	u_int16_t	me_flash_age;
	u_int8_t	me_status_flags;
	u_int8_t	me_free_state_change_count;
	u_int8_t	me_fwminor;
	u_int8_t	me_fwmajor;
	u_int8_t	me_rebuild_flag;
	u_int8_t	me_max_commands;
	u_int8_t	me_offline_sd_count;
	u_int8_t	me_res3;
	u_int8_t	me_critical_sd_count;
	u_int8_t	me_res4[3];
	u_int8_t	me_dead_count;
	u_int8_t	me_res5;
	u_int8_t	me_rebuild_count;
	u_int8_t	me_misc_flags;
	struct  {
		u_int8_t	dd_targ;
		u_int8_t	dd_chan;
	} __packed me_dead[20];
} __packed;

struct mlx_enquiry {
	u_int8_t	me_num_sys_drvs;
	u_int8_t	me_res1[3];
	u_int32_t	me_drvsize[32];
	u_int16_t	me_flash_age;
	u_int8_t	me_status_flags;
#define	MLX_ENQ_SFLAG_DEFWRERR	0x01	/* deferred write error indicator */
#define	MLX_ENQ_SFLAG_BATTLOW	0x02	/* battery low */
	u_int8_t	me_res2;
	u_int8_t	me_fwminor;
	u_int8_t	me_fwmajor;
	u_int8_t	me_rebuild_flag;
	u_int8_t	me_max_commands;
	u_int8_t	me_offline_sd_count;
	u_int8_t	me_res3;
	u_int16_t	me_event_log_seq_num;
	u_int8_t	me_critical_sd_count;
	u_int8_t	me_res4[3];
	u_int8_t	me_dead_count;
	u_int8_t	me_res5;
	u_int8_t	me_rebuild_count;
	u_int8_t	me_misc_flags;
#define	MLX_ENQ_MISC_BBU	0x08	/* battery backup present */
	struct {
		u_int8_t	dd_targ;
		u_int8_t	dd_chan;
	} __packed me_dead[20];
} __packed;

struct mlx_enquiry2 {
	u_int8_t	me_hardware_id[4];
	u_int8_t	me_firmware_id[4];
	u_int32_t	me_res1;
	u_int8_t	me_configured_channels;
	u_int8_t	me_actual_channels;
	u_int8_t	me_max_targets;
	u_int8_t	me_max_tags;
	u_int8_t	me_max_sys_drives;
	u_int8_t	me_max_arms;
	u_int8_t	me_max_spans;
	u_int8_t	me_res2;
	u_int32_t	me_res3;
	u_int32_t	me_mem_size;
	u_int32_t	me_cache_size;
	u_int32_t	me_flash_size;
	u_int32_t	me_nvram_size;
	u_int16_t	me_mem_type;
	u_int16_t	me_clock_speed;
	u_int16_t	me_mem_speed;
	u_int16_t	me_hardware_speed;
	u_int8_t	me_res4[12];
	u_int16_t	me_max_commands;
	u_int16_t	me_max_sg;
	u_int16_t	me_max_dp;
	u_int16_t	me_max_iod;
	u_int16_t	me_max_comb;
	u_int8_t	me_latency;
	u_int8_t	me_res5;
	u_int8_t	me_scsi_timeout;
	u_int8_t	me_res6;
	u_int16_t	me_min_freelines;
	u_int8_t	me_res7[8];
	u_int8_t	me_rate_const;
	u_int8_t	me_res8[11];
	u_int16_t	me_physblk;
	u_int16_t	me_logblk;
	u_int16_t	me_maxblk;
	u_int16_t	me_blocking_factor;
	u_int16_t	me_cacheline;
	u_int8_t	me_scsi_cap;
	u_int8_t	me_res9[5];
	u_int16_t	me_firmware_build;
	u_int8_t	me_fault_mgmt_type;
	u_int8_t	me_res10;
	u_int32_t	me_firmware_features;
	u_int8_t	me_res11[8];
} __packed;

/* MLX_CMD_ENQSYSDRIVE returns an array of 32 of these. */
struct mlx_enq_sys_drive {
	u_int32_t	sd_size;
	u_int8_t	sd_state;
	u_int8_t	sd_raidlevel;
	u_int16_t	sd_res1;
} __packed;

/*
 * MLX_CMD_LOGOP/MLX_LOGOP_GET
 *
 * Bitfields:
 *
 * 0-4	el_target	SCSI target
 * 5-7  el_target	SCSI channel
 * 0-6	el_errorcode	error code
 * 7-7	el_errorcode	validity (?)
 * 0-3	el_sense	sense key
 * 4-4	el_sense	reserved
 * 5-5	el_sense	ILI
 * 6-6	el_sense	EOM
 * 7-7	el_sense	filemark
 */
struct mlx_eventlog_entry {
	u_int8_t	el_type;
	u_int8_t	el_length;
	u_int8_t	el_target;
	u_int8_t	el_lun;
	u_int16_t	el_seqno;
	u_int8_t	el_errorcode;
	u_int8_t	el_segment;
	u_int8_t	el_sense;
	u_int8_t	el_information[4];
	u_int8_t	el_addsense;
	u_int8_t	el_csi[4];
	u_int8_t	el_asc;
	u_int8_t	el_asq;
	u_int8_t	el_res3[12];
} __packed;

#define	MLX_LOGOP_GET		0x00	/* operation codes for MLX_CMD_LOGOP */
#define	MLX_LOGMSG_SENSE	0x00	/* log message contents codes */

struct mlx_rebuild_stat {
	u_int32_t	rb_drive;
	u_int32_t	rb_size;
	u_int32_t	rb_remaining;
} __packed;

struct mlx_config {
	u_int16_t	cf_flags1;
#define	MLX_CF2_ACTV_NEG	0x0002
#define	MLX_CF2_NORSTRTRY	0x0080
#define	MLX_CF2_STRGWRK		0x0100
#define	MLX_CF2_HPSUPP		0x0200
#define	MLX_CF2_NODISCN		0x0400
#define	MLX_CF2_ARM		0x2000
#define	MLX_CF2_OFM		0x8000
#define	MLX_CF2_AEMI		(MLX_CF2_ARM | MLX_CF2_OFM)
	u_int8_t	cf_oemid;
	u_int8_t	cf_oem_model;
	u_int8_t	cf_physical_sector;
	u_int8_t	cf_logical_sector;
	u_int8_t	cf_blockfactor;
	u_int8_t	cf_flags2;
#define	MLX_CF2_READAH		0x01
#define	MLX_CF2_BIOSDLY		0x02
#define	MLX_CF2_REASS1S		0x10
#define	MLX_CF2_FUAENABL	0x40
#define	MLX_CF2_R5ALLS		0x80
	u_int8_t	cf_rcrate;
	u_int8_t	cf_res1;
	u_int8_t	cf_blocks_per_cache_line;
	u_int8_t	cf_blocks_per_stripe;
	u_int8_t	cf_scsi_param_0;
	u_int8_t	cf_scsi_param_1;
	u_int8_t	cf_scsi_param_2;
	u_int8_t	cf_scsi_param_3;
	u_int8_t	cf_scsi_param_4;
	u_int8_t	cf_scsi_param_5;
	u_int8_t	cf_scsi_initiator_id;
	u_int8_t	cf_res2;
	u_int8_t	cf_startup_mode;
	u_int8_t	cf_simultaneous_spinup_devices;
	u_int8_t	cf_delay_between_spinups;
	u_int8_t	cf_res3;
	u_int16_t	cf_checksum;
} __packed;

struct mlx_config2 {
	struct mlx_config cf2_cf;
	u_int8_t	cf2_reserved0[26];
	u_int8_t	cf2_flags;
#define	MLX_CF2_BIOS_DIS	0x01
#define	MLX_CF2_CDROM_DIS	0x02
#define	MLX_CF2_GEOM_255	0x20
	u_int8_t	cf2_reserved1[9];
	u_int16_t	cf2_checksum;
} __packed;

struct mlx_sys_drv_span {
	u_int32_t	sp_start_lba;
	u_int32_t	sp_nblks;
	u_int8_t	sp_arm[8];
} __packed;

struct mlx_sys_drv {
	u_int8_t	sd_status;
	u_int8_t	sd_ext_status;
	u_int8_t	sd_mod1;
	u_int8_t	sd_mod2;
	u_int8_t	sd_raidlevel;
#define	MLX_SYS_DRV_WRITEBACK	(1<<7)
#define	MLX_SYS_DRV_RAID0	0
#define	MLX_SYS_DRV_RAID1	1
#define	MLX_SYS_DRV_RAID3	3
#define	MLX_SYS_DRV_RAID5	5
#define	MLX_SYS_DRV_RAID6	6
#define	MLX_SYS_DRV_JBOD	7
	u_int8_t	sd_valid_arms;
	u_int8_t	sd_valid_spans;
	u_int8_t	sd_init_state;
#define	MLX_SYS_DRV_INITTED	0x81;
	struct	mlx_sys_drv_span sd_span[4];
} __packed;

struct mlx_phys_drv {
	u_int8_t	pd_flags1;
#define	MLX_PHYS_DRV_PRESENT	0x01
	u_int8_t	pd_flags2;
#define	MLX_PHYS_DRV_OTHER	0x00
#define	MLX_PHYS_DRV_DISK	0x01
#define	MLX_PHYS_DRV_SEQUENTIAL	0x02
#define	MLX_PHYS_DRV_CDROM	0x03
#define	MLX_PHYS_DRV_FAST20	0x08
#define	MLX_PHYS_DRV_SYNC	0x10
#define	MLX_PHYS_DRV_FAST	0x20
#define	MLX_PHYS_DRV_WIDE	0x40
#define	MLX_PHYS_DRV_TAG	0x80
	u_int8_t	pd_status;
#define	MLX_PHYS_DRV_DEAD	0x00
#define	MLX_PHYS_DRV_WRONLY	0x02
#define	MLX_PHYS_DRV_ONLINE	0x03
#define	MLX_PHYS_DRV_STANDBY	0x10
	u_int8_t	pd_res1;
	u_int8_t	pd_period;
	u_int8_t	pd_offset;
	u_int32_t	pd_config_size;
} __packed;

struct mlx_core_cfg {
	u_int8_t	cc_num_sys_drives;
	u_int8_t	cc_res1[3];
	struct	mlx_sys_drv cc_sys_drives[32];
	struct	mlx_phys_drv cc_phys_drives[5 * 16];
} __packed;

/*
 * Bitfields:
 *
 * 0-3	dcdb_target	SCSI target
 * 4-7	dcdb_target	SCSI channel
 * 0-3	dcdb_length	CDB length
 * 4-7	dcdb_length	high 4 bits of `datasize'
 */
struct mlx_dcdb {
	u_int8_t	dcdb_target;
	u_int8_t	dcdb_flags;
#define	MLX_DCDB_NO_DATA	0x00
#define	MLX_DCDB_DATA_IN	0x01
#define	MLX_DCDB_DATA_OUT	0x02
#define	MLX_DCDB_EARLY_STATUS	0x04
#define	MLX_DCDB_TIMEOUT_10S	0x10	/* This lot is wrong? [ad] */
#define	MLX_DCDB_TIMEOUT_60S	0x20
#define	MLX_DCDB_TIMEOUT_20M	0x30
#define	MLX_DCDB_TIMEOUT_24H	0x40
#define	MLX_DCDB_NO_AUTO_SENSE	0x40	/* XXX ?? */
#define	MLX_DCDB_DISCONNECT	0x80
	u_int16_t	dcdb_datasize;
	u_int32_t	dcdb_physaddr;
	u_int8_t	dcdb_length;
	u_int8_t	dcdb_sense_length;
	u_int8_t	dcdb_cdb[12];
	u_int8_t	dcdb_sense[64];
	u_int8_t	dcdb_status;
	u_int8_t	res1;
} __packed;

struct mlx_bbtable_entry {
	u_int32_t	bbt_block_number;
	u_int8_t	bbt_extent;
	u_int8_t	bbt_res1;
	u_int8_t	bbt_entry_type;
	u_int8_t	bbt_system_drive;	/* high 3 bits reserved */
} __packed;

#endif	/* !_IC_MLXREG_H_ */