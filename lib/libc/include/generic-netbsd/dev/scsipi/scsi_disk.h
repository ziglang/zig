/*	$NetBSD: scsi_disk.h,v 1.34 2021/11/10 16:17:34 msaitoh Exp $	*/

/*
 * SCSI-specific interface description
 */

/*
 * Some lines of this file come from a file of the name "scsi.h"
 * distributed by OSF as part of mach2.5,
 *  so the following disclaimer has been kept.
 *
 * Copyright 1990 by Open Software Foundation,
 * Grenoble, FRANCE
 *
 * 		All Rights Reserved
 *
 *   Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose and without fee is hereby granted,
 * provided that the above copyright notice appears in all copies and
 * that both the copyright notice and this permission notice appear in
 * supporting documentation, and that the name of OSF or Open Software
 * Foundation not be used in advertising or publicity pertaining to
 * distribution of the software without specific, written prior
 * permission.
 *
 *   OSF DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS,
 * IN NO EVENT SHALL OSF BE LIABLE FOR ANY SPECIAL, INDIRECT, OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
 * LOSS OF USE, DATA OR PROFITS, WHETHER IN ACTION OF CONTRACT,
 * NEGLIGENCE, OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
 * WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
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

/*
 * SCSI command format
 */
#ifndef _DEV_SCSIPI_SCSI_DISK_H_
#define _DEV_SCSIPI_SCSI_DISK_H_

/*
 * XXX Is this also used by ATAPI?
 */
#define	SCSI_FORMAT_UNIT		0x04
struct scsi_format_unit {
	u_int8_t opcode;
	u_int8_t flags;
#define	SFU_DLF_MASK	0x07
#define	SFU_CMPLST	0x08
#define	SFU_FMTDATA	0x10
	u_int8_t vendor_specific;
	u_int8_t interleave[2];
	u_int8_t control;
};

/*
 * If the FmtData bit is set, a FORMAT UNIT parameter list is transferred
 * to the target during the DATA OUT phase.  The parameter list includes
 *
 *	Defect list header
 *	Initialization pattern descriptor (if any)
 *	Defect descriptor(s) (if any)
 */

struct scsi_format_unit_defect_list_header {
	u_int8_t reserved;
	u_int8_t flags;
#define	DLH_VS		0x01		/* vendor specific */
#define	DLH_IMMED	0x02		/* immediate return */
#define	DLH_DSP		0x04		/* disable saving parameters */
#define	DLH_IP		0x08		/* initialization pattern */
#define	DLH_STPF	0x10		/* stop format */
#define	DLH_DCRT	0x20		/* disable certification */
#define	DLH_DPRY	0x40		/* disable primary */
#define	DLH_FOV		0x80		/* format options valid */
	u_int8_t defect_lst_len[2];
};

/*
 * See Table 117 of the SCSI-2 specification for a description of
 * the IP modifier.
 */
struct scsi_initialization_pattern_descriptor {
	u_int8_t ip_modifier;
	u_int8_t pattern_type;
#define	IP_TYPE_DEFAULT		0x01
#define	IP_TYPE_REPEAT		0x01
				/* 0x02 -> 0x7f: reserved */
				/* 0x80 -> 0xff: vendor-specific */
	u_int8_t pattern_length[2];
#if 0
	u_int8_t pattern[...];
#endif
};

/*
 * Defect descriptors.  These are used as the defect lists in the FORMAT UNIT
 * and READ DEFECT DATA commands, and as the translate page of the
 * SEND DIAGNOSTIC and RECEIVE DIAGNOSTIC RESULTS commands.
 */

/* Block format */
struct scsi_defect_descriptor_bf {
	u_int8_t block_address[4];
};

/* Bytes from index format */
struct scsi_defect_descriptor_bfif {
	u_int8_t cylinder[3];
	u_int8_t head;
	u_int8_t bytes_from_index[4];
};

/* Physical sector format */
struct scsi_defect_descriptor_psf {
	u_int8_t cylinder[3];
	u_int8_t head;
	u_int8_t sector[4];
};

/*
 * XXX for now this isn't in the ATAPI specs, but if there are on day
 * ATAPI hard disks, it is likely that they implement this command (or a
 * command like this ?
 */
#define	SCSI_REASSIGN_BLOCKS		0x07
struct scsi_reassign_blocks {
	u_int8_t opcode;
	u_int8_t byte2;
	u_int8_t unused[3];
	u_int8_t control;
};

/*
 * XXX Is this also used by ATAPI?
 */
#define	SCSI_REZERO_UNIT		0x01
struct scsi_rezero_unit {
	u_int8_t opcode;
	u_int8_t byte2;
	u_int8_t reserved[3];
	u_int8_t control;
};

#define	SCSI_READ_6_COMMAND		0x08
#define SCSI_WRITE_6_COMMAND		0x0a
struct scsi_rw_6 {
	u_int8_t opcode;
	u_int8_t addr[3];
#define	SRW_TOPADDR	0x1F	/* only 5 bits here */
	u_int8_t length;
	u_int8_t control;
};

/*
 * XXX Does ATAPI have an equivalent?
 */
#define	SCSI_SYNCHRONIZE_CACHE_10	0x35
struct scsi_synchronize_cache_10 {
	u_int8_t opcode;
	u_int8_t flags;
#define	SSC_RELADR	0x01		/* obsolete */
#define	SSC_IMMED	0x02
#define	SSC_SYNC_NV	0x04
	u_int8_t addr[4];
	u_int8_t byte7;
	u_int8_t length[2];
	u_int8_t control;
};

/*
 * XXX Does ATAPI have an equivalent?
 */
#define SCSI_READ_DEFECT_DATA		0x37
struct scsi_read_defect_data {
	 u_int8_t opcode;
	 u_int8_t byte2;
#define RDD_PRIMARY	0x10
#define RDD_GROWN	0x08
#define RDD_BF		0x00
#define RDD_BFIF	0x04
#define RDD_PSF		0x05
	 u_int8_t flags;
	 u_int8_t reserved[4];
	 u_int8_t length[2];
	 u_int8_t control;
};

#define	SCSI_SYNCHRONIZE_CACHE_16	0x91
struct scsi_synchronize_cache_16 {
	u_int8_t opcode;
	u_int8_t flags;			/* see SYNCHRONIZE CACHE (10) */
	u_int8_t addr[8];
	u_int8_t length[4];
	u_int8_t byte15;
	u_int8_t control;
};

/* DATAs definitions for the above commands */

struct scsi_reassign_blocks_data {
	u_int8_t reserved[2];
	u_int8_t length[2];
	struct {
		u_int8_t dlbaddr[4];
	} defect_descriptor[1];
};

struct scsi_read_defect_data_data {
	u_int8_t reserved;
	u_int8_t flags;
	u_int8_t length[2];
	union scsi_defect_descriptor {
		struct scsi_defect_descriptor_bf bf;
		struct scsi_defect_descriptor_bfif bfif;
		struct scsi_defect_descriptor_psf psf;
	} defect_descriptor[1];
};

union scsi_disk_pages {
#define	DISK_PGCODE	0x3F	/* only 6 bits valid */
	struct page_err_recov {
		u_int8_t pg_code;	/* page code (should be 1) */
		u_int8_t pg_length;	/* page length (should be 0x0a) */
		u_int8_t flags;		/* error recovery flags */
#define	ERR_RECOV_DCR	0x01		/* disable correction */
#define	ERR_RECOV_DTE	0x02		/* disable transfer on error */
#define	ERR_RECOV_PER	0x04		/* post error */
#define	ERR_RECOV_EER	0x08		/* enable early recovery */
#define	ERR_RECOV_RC	0x10		/* read continuous */
#define	ERR_RECOV_TB	0x20		/* transfer block */
#define	ERR_RECOV_ARRE	0x40		/* autom. read reallocation enable */
#define	ERR_RECOV_AWRE	0x80		/* autom. write reallocation enable */
		u_int8_t rd_retry_ct;	/* read retry count */
		u_int8_t corr_span;	/* correction span */
		u_int8_t hd_off_ct;	/* head offset count */
		u_int8_t dat_strb_off_ct; /* data strobe offset count */
		u_int8_t reserved1;
		u_int8_t wr_retry_ct;	/* write retry count */
		u_int8_t reserved2;
		u_int8_t recov_tm_lim[2]; /* recovery time limit */
	} err_recov_params;
	struct page_disk_format {
		u_int8_t pg_code;	/* page code (should be 3) */
		u_int8_t pg_length;	/* page length (should be 0x16) */
		u_int8_t trk_z[2];	/* tracks per zone */
		u_int8_t alt_sec[2];	/* alternate sectors per zone */
		u_int8_t alt_trk_z[2];	/* alternate tracks per zone */
		u_int8_t alt_trk_v[2];	/* alternate tracks per volume */
		u_int8_t ph_sec_t[2];	/* physical sectors per track */
		u_int8_t bytes_s[2];	/* bytes per sector */
		u_int8_t interleave[2];	/* interleave */
		u_int8_t trk_skew[2];	/* track skew factor */
		u_int8_t cyl_skew[2];	/* cylinder skew */
		u_int8_t flags;		/* various */
#define	DISK_FMT_SURF	0x10
#define	DISK_FMT_RMB	0x20
#define	DISK_FMT_HSEC	0x40
#define	DISK_FMT_SSEC	0x80
		u_int8_t reserved1;
		u_int8_t reserved2;
		u_int8_t reserved3;
	} disk_format;
	struct page_rigid_geometry {
		u_int8_t pg_code;	/* page code (should be 4) */
		u_int8_t pg_length;	/* page length (should be 0x16)	*/
		u_int8_t ncyl[3];	/* number of cylinders */
		u_int8_t nheads;	/* number of heads */
		u_int8_t st_cyl_wp[3];	/* starting cyl., write precomp */
		u_int8_t st_cyl_rwc[3];	/* starting cyl., red. write cur */
		u_int8_t driv_step[2];	/* drive step rate */
		u_int8_t land_zone[3];	/* landing zone cylinder */
		u_int8_t sp_sync_ctl;	/* spindle synch control */
#define SPINDLE_SYNCH_MASK	0x03	/* mask of valid bits */
#define SPINDLE_SYNCH_NONE	0x00	/* synch disabled or not supported */
#define SPINDLE_SYNCH_SLAVE	0x01	/* disk is a slave */
#define SPINDLE_SYNCH_MASTER	0x02	/* disk is a master */
#define SPINDLE_SYNCH_MCONTROL	0x03	/* disk is a master control */
		u_int8_t rot_offset;	/* rotational offset (for spindle synch) */
		u_int8_t reserved1;
		u_int8_t rpm[2];	/* media rotation speed */
		u_int8_t reserved2;
		u_int8_t reserved3;
    	} rigid_geometry;
	struct page_flex_geometry {
		u_int8_t pg_code;	/* page code (should be 5) */
		u_int8_t pg_length;	/* page length (should be 0x1e) */
		u_int8_t xfr_rate[2];
		u_int8_t nheads;	/* number of heads */
		u_int8_t ph_sec_tr;	/* physical sectors per track */
		u_int8_t bytes_s[2];	/* bytes per sector */
		u_int8_t ncyl[2];	/* number of cylinders */
		u_int8_t st_cyl_wp[2];	/* start cyl., write precomp */
		u_int8_t st_cyl_rwc[2];	/* start cyl., red. write cur */
		u_int8_t driv_step[2];	/* drive step rate */
		u_int8_t driv_step_w;	/* drive step pulse width */
		u_int8_t head_settle[2];/* head settle delay */
		u_int8_t motor_on;	/* motor on delay */
		u_int8_t motor_off;	/* motor off delay */
		u_int8_t flags;		/* various flags */
#define MOTOR_ON		0x20	/* motor on (pin 16)? */
#define START_AT_SECTOR_1	0x40	/* start at sector 1  */
#define READY_VALID		0x20	/* RDY (pin 34) valid */
		u_int8_t step_p_cyl;	/* step pulses per cylinder */
		u_int8_t write_pre;	/* write precompensation */
		u_int8_t head_load;	/* head load delay */
		u_int8_t head_unload;	/* head unload delay */
		u_int8_t pin_34_2;	/* pin 34 (6) pin 2 (7/11) definition */
		u_int8_t pin_4_1;	/* pin 4 (8/9) pin 1 (13) definition */
		u_int8_t rpm[2];	/* rotational rate */
		u_int8_t reserved1;
		u_int8_t reserved2;
	} flex_geometry;
	struct page_caching {
		u_int8_t pg_code;	/* page code (should be 8) */
		u_int8_t pg_length;	/* page length (should be 0x0a) */
		u_int8_t flags;		/* cache parameter flags */
#define	CACHING_RCD	0x01		/* read cache disable */
#define	CACHING_MF	0x02		/* multiplcation factor */
#define	CACHING_WCE	0x04		/* write cache enable (write-back) */
#define	CACHING_SIZE	0x08		/* use CACHE SEGMENT SIZE */
#define	CACHING_DISC	0x10		/* pftch across time discontinuities */
#define	CACHING_CAP	0x20		/* caching analysis permitted */
#define	CACHING_ABPF	0x40		/* abort prefetch */
#define	CACHING_IC	0x80		/* initiator control */
		u_int8_t ret_prio;	/* retention priority */
#define	READ_RET_PRIO_SHIFT 4
#define	RET_PRIO_DONT_DISTINGUISH	0x0
#define	RET_PRIO_REPLACE_READ_WRITE	0x1
#define	RET_PRIO_REPLACE_PREFETCH	0xf
		u_int8_t dis_prefetch_xfer_len[2];
		u_int8_t min_prefetch[2];
		u_int8_t max_prefetch[2];
		u_int8_t max_prefetch_ceiling[2];
		u_int8_t flags2;	/* additional cache param flags */
#define	CACHING2_VS0	0x08		/* vendor specific bit */
#define	CACHING2_VS1	0x10		/* vendor specific bit */
#define	CACHING2_DRA	0x20		/* disable read ahead */
#define	CACHING2_LBCSS	0x40		/* CACHE SEGMENT SIZE is blocks */
#define	CACHING2_FSW	0x80		/* force sequential write */
		u_int8_t num_cache_segments;
		u_int8_t cache_segment_size[2];
		u_int8_t reserved1;
		u_int8_t non_cache_segment_size[2];
	} caching_params;
	struct page_control {
		u_int8_t pg_code;	/* page code (should be 0x0a) */
		u_int8_t pg_length;	/* page length (should be 0x0a) */
		u_int8_t ctl_flags1;	/* First set of flags */
#define CTL1_TST_PER_INTR 	0x40	/* Task set per initiator */
#define CTL1_TST_FIELD		0xe0	/* Full field */
#define CTL1_D_SENSE		0x04	/* Descriptor-format sense return */
#define CTL1_GLTSD		0x02	/* Glob. Log Targ. Save Disable */
#define CTL1_RLEC		0x01	/* Rpt Logging Exception Condition */
		u_int8_t ctl_flags2;	/* Second set of flags */
#define CTL2_QAM_UNRESTRICT 0x10	/* Unrestricted reordering allowed */
#define CTL2_QAM_FIELD		0xf0	/* Full Queue alogo. modifier field */
#define CTL2_QERR_ABRT		0x02	/* Queue error - abort all */
#define CTL2_QERR_ABRT_SELF	0x06	/* Queue error - abort intr's */
#define CTL2_QERR_FIELD		0x06	/* Full field */
#define CTL2_DQUE		0x01	/* Disable queuing */
		u_int8_t ctl_flags3;	/* Third set of flags */
#define CTL3_TAS		0x80	/* other-intr aborts generate status */
#define CTL3_RAC		0x40	/* Report A Check */
#define CTL3_UAIC_RET		0x10	/* retain UA, see SPC-3 */
#define CTL3_UAIC_RET_EST	0x30	/* retain UA and establish UA */
#define CTL3_UA_INTRLOCKS	0x30	/* UA Interlock control field */
#define CTL3_SWP		0x08	/* Software write protect */
#define CTL3_RAERP		0x04	/* (unit) Ready AER Permission */
#define CTL3_UAAERP		0x02	/* Unit Attention AER Permission */
#define CTL3_EAERP		0x01	/* Error AER Permission */
		u_int8_t ctl_autoload;	/* autoload mode control */
#define CTL_AUTOLOAD_FIELD	0x07	/* autoload field */
		u_int8_t ctl_r_hld[2];	/* RAERP holdoff period */
		u_int8_t ctl_busy[2];	/* busy timeout period */
		u_int8_t ctl_selt[2];	/* extended self-test completion time */
	} control_params;
};

#endif /* _DEV_SCSIPI_SCSI_DISK_H_ */