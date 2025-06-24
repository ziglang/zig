/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2000, 2002 Kenneth D. Merry
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions, and the following disclaimer,
 *    without modification, immediately at the beginning of the file.
 * 2. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */
/*
 * Written by Julian Elischer (julian@tfs.com)
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
 *
 *	from: scsi_cd.h,v 1.10 1997/02/22 09:44:28 peter Exp $
 */
#ifndef	_SCSI_SCSI_CD_H
#define _SCSI_SCSI_CD_H 1

/*
 *	Define two bits always in the same place in byte 2 (flag byte)
 */
#define	CD_RELADDR	0x01
#define	CD_MSF		0x02

/*
 * SCSI command format
 */

struct scsi_get_config
{
	uint8_t opcode;
	uint8_t rt;
#define	SGC_RT_ALL		0x00
#define	SGC_RT_CURRENT		0x01
#define	SGC_RT_SPECIFIC		0x02
#define	SGC_RT_MASK		0x03
	uint8_t starting_feature[2];
	uint8_t reserved[3];
	uint8_t length[2];
	uint8_t control;
};

struct scsi_get_config_header
{
	uint8_t data_length[4];
	uint8_t reserved[2];
	uint8_t current_profile[2];
};

struct scsi_get_config_feature
{
	uint8_t feature_code[2];
	uint8_t flags;
#define	SGC_F_CURRENT		0x01
#define	SGC_F_PERSISTENT	0x02
#define	SGC_F_VERSION_MASK	0x2C
#define	SGC_F_VERSION_SHIFT	2
	uint8_t add_length;
	uint8_t feature_data[];
};

struct scsi_get_event_status
{
	uint8_t opcode;
	uint8_t byte2;
#define	SGESN_POLLED		1
	uint8_t reserved[2];
	uint8_t notif_class;
	uint8_t reserved2[2];
	uint8_t length[2];
	uint8_t control;
};

struct scsi_get_event_status_header
{
	uint8_t descr_length[4];
	uint8_t nea_class;
#define	SGESN_NEA		0x80
	uint8_t supported_class;
};

struct scsi_get_event_status_descr
{
	uint8_t event_code;
	uint8_t event_info[];
};

struct scsi_mechanism_status
{
	uint8_t opcode;
	uint8_t reserved[7];
	uint8_t length[2];
	uint8_t reserved2;
	uint8_t control;
};

struct scsi_mechanism_status_header
{
	uint8_t state1;
	uint8_t state2;
	uint8_t lba[3];
	uint8_t slots_num;
	uint8_t slots_length[2];
};

struct scsi_pause
{
	uint8_t op_code;
	uint8_t byte2;
	uint8_t unused[6];
	uint8_t resume;
	uint8_t control;
};
#define	PA_PAUSE	1
#define PA_RESUME	0

struct scsi_play_msf
{
	uint8_t op_code;
	uint8_t byte2;
	uint8_t unused;
	uint8_t start_m;
	uint8_t start_s;
	uint8_t start_f;
	uint8_t end_m;
	uint8_t end_s;
	uint8_t end_f;
	uint8_t control;
};

struct scsi_play_track
{
	uint8_t op_code;
	uint8_t byte2;
	uint8_t unused[2];
	uint8_t start_track;
	uint8_t start_index;
	uint8_t unused1;
	uint8_t end_track;
	uint8_t end_index;
	uint8_t control;
};

struct scsi_play_10
{
	uint8_t op_code;
	uint8_t byte2;
	uint8_t blk_addr[4];
	uint8_t unused;
	uint8_t xfer_len[2];
	uint8_t control;
};

struct scsi_play_12
{
	uint8_t op_code;
	uint8_t byte2;	/* same as above */
	uint8_t blk_addr[4];
	uint8_t xfer_len[4];
	uint8_t unused;
	uint8_t control;
};

struct scsi_play_rel_12
{
	uint8_t op_code;
	uint8_t byte2;	/* same as above */
	uint8_t blk_addr[4];
	uint8_t xfer_len[4];
	uint8_t track;
	uint8_t control;
};

struct scsi_read_header
{
	uint8_t op_code;
	uint8_t byte2;
	uint8_t blk_addr[4];
	uint8_t unused;
	uint8_t data_len[2];
	uint8_t control;
};

struct scsi_read_subchannel
{
	uint8_t op_code;
	uint8_t byte1;
	uint8_t byte2;
#define	SRS_SUBQ	0x40
	uint8_t subchan_format;
	uint8_t unused[2];
	uint8_t track;
	uint8_t data_len[2];
	uint8_t control;
};

struct scsi_read_toc
{
	uint8_t op_code;
	uint8_t byte2;
	uint8_t format;
#define	SRTOC_FORMAT_TOC	0x00
#define	SRTOC_FORMAT_LAST_ADDR	0x01
#define	SRTOC_FORMAT_QSUB_TOC	0x02
#define	SRTOC_FORMAT_QSUB_PMA	0x03
#define	SRTOC_FORMAT_ATIP	0x04
#define	SRTOC_FORMAT_CD_TEXT	0x05
	uint8_t unused[3];
	uint8_t from_track;
	uint8_t data_len[2];
	uint8_t control;
};

struct scsi_read_toc_hdr
{
	uint8_t data_length[2];
	uint8_t first;
	uint8_t last;
};

struct scsi_read_toc_type01_descr
{
	uint8_t reserved;
	uint8_t addr_ctl;
	uint8_t track_number;
	uint8_t reserved2;
	uint8_t track_start[4];
};

struct scsi_read_cd_capacity
{
	uint8_t op_code;
	uint8_t byte2;
	uint8_t addr_3;	/* Most Significant */
	uint8_t addr_2;
	uint8_t addr_1;
	uint8_t addr_0;	/* Least Significant */
	uint8_t unused[3];
	uint8_t control;
};

struct scsi_set_speed
{
	uint8_t opcode;
	uint8_t byte2;
	uint8_t readspeed[2];
	uint8_t writespeed[2];
	uint8_t reserved[5];
	uint8_t control;
};

struct scsi_report_key 
{
	uint8_t opcode;
	uint8_t reserved0;
	uint8_t lba[4];
	uint8_t reserved1[2];
	uint8_t alloc_len[2];
	uint8_t agid_keyformat;
#define RK_KF_AGID_MASK		0xc0
#define RK_KF_AGID_SHIFT	6
#define RK_KF_KEYFORMAT_MASK	0x3f
#define RK_KF_AGID		0x00
#define RK_KF_CHALLENGE		0x01
#define RF_KF_KEY1		0x02
#define RK_KF_KEY2		0x03
#define RF_KF_TITLE		0x04
#define RF_KF_ASF		0x05
#define RK_KF_RPC_SET		0x06
#define RF_KF_RPC_REPORT	0x08
#define RF_KF_INV_AGID		0x3f
	uint8_t control;
};

/*
 * See the report key structure for key format and AGID definitions.
 */
struct scsi_send_key
{
	uint8_t opcode;
	uint8_t reserved[7];
	uint8_t param_len[2];
	uint8_t agid_keyformat;
	uint8_t control;
};

struct scsi_read_dvd_structure
{
	uint8_t opcode;
	uint8_t reserved;
	uint8_t address[4];
	uint8_t layer_number;
	uint8_t format;
#define RDS_FORMAT_PHYSICAL		0x00
#define RDS_FORMAT_COPYRIGHT		0x01
#define RDS_FORMAT_DISC_KEY		0x02
#define RDS_FORMAT_BCA			0x03
#define RDS_FORMAT_MANUFACTURER		0x04
#define RDS_FORMAT_CMGS_CPM		0x05
#define RDS_FORMAT_PROT_DISCID		0x06
#define RDS_FORMAT_DISC_KEY_BLOCK	0x07
#define RDS_FORMAT_DDS			0x08
#define RDS_FORMAT_DVDRAM_MEDIA_STAT	0x09
#define RDS_FORMAT_SPARE_AREA		0x0a
#define RDS_FORMAT_RMD_BORDEROUT	0x0c
#define RDS_FORMAT_RMD			0x0d
#define RDS_FORMAT_LEADIN		0x0e
#define RDS_FORMAT_DISC_ID		0x0f
#define RDS_FORMAT_DCB			0x30
#define RDS_FORMAT_WRITE_PROT		0xc0
#define RDS_FORMAT_STRUCTURE_LIST	0xff
	uint8_t alloc_len[2];
	uint8_t agid;
	uint8_t control;
};

/*
 * Opcodes
 */
#define READ_CD_CAPACITY	0x25	/* slightly different from disk */
#define READ_SUBCHANNEL		0x42	/* cdrom read Subchannel */
#define READ_TOC		0x43	/* cdrom read TOC */
#define READ_HEADER		0x44	/* cdrom read header */
#define PLAY_10			0x45	/* cdrom play  'play audio' mode */
#define GET_CONFIGURATION	0x46	/* Get device configuration */
#define PLAY_MSF		0x47	/* cdrom play Min,Sec,Frames mode */
#define PLAY_TRACK		0x48	/* cdrom play track/index mode */
#define PLAY_TRACK_REL		0x49	/* cdrom play track/index mode */
#define GET_EVENT_STATUS	0x4a	/* Get event status notification */
#define PAUSE			0x4b	/* cdrom pause in 'play audio' mode */
#define SEND_KEY		0xa3	/* dvd send key command */
#define REPORT_KEY		0xa4	/* dvd report key command */
#define PLAY_12			0xa5	/* cdrom pause in 'play audio' mode */
#define PLAY_TRACK_REL_BIG	0xa9	/* cdrom play track/index mode */
#define READ_DVD_STRUCTURE	0xad	/* read dvd structure */
#define SET_CD_SPEED		0xbb	/* set c/dvd speed */
#define MECHANISM_STATUS	0xbd	/* get status of c/dvd mechanics */

struct scsi_report_key_data_header
{
	uint8_t data_len[2];
	uint8_t reserved[2];
};

struct scsi_report_key_data_agid
{
	uint8_t data_len[2];
	uint8_t reserved[5];
	uint8_t agid;
#define RKD_AGID_MASK	0xc0
#define RKD_AGID_SHIFT	6
};

struct scsi_report_key_data_challenge
{
	uint8_t data_len[2];
	uint8_t reserved0[2];
	uint8_t challenge_key[10];
	uint8_t reserved1[2];
};

struct scsi_report_key_data_key1_key2
{
	uint8_t data_len[2];
	uint8_t reserved0[2];
	uint8_t key1[5];
	uint8_t reserved1[3];
};

struct scsi_report_key_data_title
{
	uint8_t data_len[2];
	uint8_t reserved0[2];
	uint8_t byte0;
#define RKD_TITLE_CPM		0x80
#define RKD_TITLE_CPM_SHIFT	7
#define RKD_TITLE_CP_SEC	0x40
#define RKD_TITLE_CP_SEC_SHIFT	6
#define RKD_TITLE_CMGS_MASK	0x30
#define RKD_TITLE_CMGS_SHIFT	4
#define RKD_TITLE_CMGS_NO_RST	0x00
#define RKD_TITLE_CMGS_RSVD	0x10
#define RKD_TITLE_CMGS_1_GEN	0x20
#define RKD_TITLE_CMGS_NO_COPY	0x30
	uint8_t title_key[5];
	uint8_t reserved1[2];
};

struct scsi_report_key_data_asf
{
	uint8_t data_len[2];
	uint8_t reserved[5];
	uint8_t success;
#define RKD_ASF_SUCCESS	0x01
};

struct scsi_report_key_data_rpc
{
	uint8_t data_len[2];
	uint8_t rpc_scheme0;
#define RKD_RPC_SCHEME_UNKNOWN		0x00
#define RKD_RPC_SCHEME_PHASE_II		0x01
	uint8_t reserved0;
	uint8_t byte4;
#define RKD_RPC_TYPE_MASK		0xC0
#define RKD_RPC_TYPE_SHIFT		6
#define RKD_RPC_TYPE_NONE		0x00
#define RKD_RPC_TYPE_SET		0x40
#define RKD_RPC_TYPE_LAST_CHANCE	0x80
#define RKD_RPC_TYPE_PERM		0xC0
#define RKD_RPC_VENDOR_RESET_MASK	0x38
#define RKD_RPC_VENDOR_RESET_SHIFT	3
#define RKD_RPC_USER_RESET_MASK		0x07
#define RKD_RPC_USER_RESET_SHIFT	0
	uint8_t region_mask;
	uint8_t rpc_scheme1;
	uint8_t reserved1;
};

struct scsi_send_key_data_rpc
{
	uint8_t data_len[2];
	uint8_t reserved0[2];
	uint8_t region_code;
	uint8_t reserved1[3];
};

/*
 * Common header for the return data from the READ DVD STRUCTURE command.
 */
struct scsi_read_dvd_struct_data_header
{
	uint8_t data_len[2];
	uint8_t reserved[2];
};

struct scsi_read_dvd_struct_data_layer_desc
{
	uint8_t book_type_version;
#define RDSD_BOOK_TYPE_DVD_ROM	0x00
#define RDSD_BOOK_TYPE_DVD_RAM	0x10
#define RDSD_BOOK_TYPE_DVD_R	0x20
#define RDSD_BOOK_TYPE_DVD_RW	0x30
#define RDSD_BOOK_TYPE_DVD_PRW	0x90
#define RDSD_BOOK_TYPE_MASK	0xf0
#define RDSD_BOOK_TYPE_SHIFT	4
#define RDSD_BOOK_VERSION_MASK	0x0f
	/*
	 * The lower 4 bits of this field is referred to as the "minimum
	 * rate" field in MMC2, and the "maximum rate" field in MMC3.  Ugh.
	 */
	uint8_t disc_size_max_rate;
#define RDSD_DISC_SIZE_120MM	0x00
#define RDSD_DISC_SIZE_80MM	0x10
#define RDSD_DISC_SIZE_MASK	0xf0
#define RDSD_DISC_SIZE_SHIFT	4
#define RDSD_MAX_RATE_0252	0x00
#define RDSD_MAX_RATE_0504	0x01
#define RDSD_MAX_RATE_1008	0x02
#define RDSD_MAX_RATE_NOT_SPEC	0x0f
#define RDSD_MAX_RATE_MASK	0x0f
	uint8_t layer_info;
#define RDSD_NUM_LAYERS_MASK	0x60
#define RDSD_NUM_LAYERS_SHIFT	5
#define RDSD_NL_ONE_LAYER	0x00
#define RDSD_NL_TWO_LAYERS	0x20
#define RDSD_TRACK_PATH_MASK	0x10
#define RDSD_TRACK_PATH_SHIFT	4
#define RDSD_TP_PTP		0x00
#define RDSD_TP_OTP		0x10
#define RDSD_LAYER_TYPE_RO	0x01
#define RDSD_LAYER_TYPE_RECORD	0x02
#define RDSD_LAYER_TYPE_RW	0x04
#define RDSD_LAYER_TYPE_MASK	0x0f
	uint8_t density;
#define RDSD_LIN_DENSITY_0267		0x00
#define RDSD_LIN_DENSITY_0293		0x10
#define RDSD_LIN_DENSITY_0409_0435	0x20
#define RDSD_LIN_DENSITY_0280_0291	0x40
/* XXX MMC2 uses 0.176um/bit instead of 0.353 as in MMC3 */
#define RDSD_LIN_DENSITY_0353		0x80
#define RDSD_LIN_DENSITY_MASK		0xf0
#define RDSD_LIN_DENSITY_SHIFT		4
#define RDSD_TRACK_DENSITY_074		0x00
#define RDSD_TRACK_DENSITY_080		0x01
#define RDSD_TRACK_DENSITY_0615		0x02
#define RDSD_TRACK_DENSITY_MASK		0x0f
	uint8_t zeros0;
	uint8_t main_data_start[3];
#define RDSD_MAIN_DATA_START_DVD_RO	0x30000
#define RDSD_MAIN_DATA_START_DVD_RW	0x31000
	uint8_t zeros1;
	uint8_t main_data_end[3];
	uint8_t zeros2;
	uint8_t end_sector_layer0[3];
	uint8_t bca;
#define RDSD_BCA	0x80
#define RDSD_BCA_MASK	0x80
#define RDSD_BCA_SHIFT	7
	uint8_t media_specific[2031];
};

struct scsi_read_dvd_struct_data_physical
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	struct scsi_read_dvd_struct_data_layer_desc layer_desc;
};

struct scsi_read_dvd_struct_data_copyright
{
	uint8_t data_len[2];
	uint8_t reserved0[2];
	uint8_t cps_type;
#define RDSD_CPS_NOT_PRESENT	0x00
#define RDSD_CPS_DATA_EXISTS	0x01
	uint8_t region_info;
	uint8_t reserved1[2];
};

struct scsi_read_dvd_struct_data_disc_key
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	uint8_t disc_key[2048];
};

struct scsi_read_dvd_struct_data_bca
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	uint8_t bca_info[188]; /* XXX 12-188 bytes */
};

struct scsi_read_dvd_struct_data_manufacturer
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	uint8_t manuf_info[2048];
};

struct scsi_read_dvd_struct_data_copy_manage
{
	uint8_t data_len[2];
	uint8_t reserved0[2];
	uint8_t byte4;
#define RDSD_CPM_NO_COPYRIGHT	0x00
#define RDSD_CPM_HAS_COPYRIGHT	0x80
#define RDSD_CPM_MASK		0x80
#define RDSD_CMGS_COPY_ALLOWED	0x00
#define RDSD_CMGS_ONE_COPY	0x20
#define RDSD_CMGS_NO_COPIES	0x30
#define RDSD_CMGS_MASK		0x30
	uint8_t reserved1[3];
};

struct scsi_read_dvd_struct_data_prot_discid
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	uint8_t prot_discid_data[16];
};

struct scsi_read_dvd_struct_data_disc_key_blk
{
	/*
	 * Length is 0x6ffe == 28670 for CPRM, 0x3002 == 12990 for CSS2.
	 */
	uint8_t data_len[2];
	uint8_t reserved;
	uint8_t total_packs;
	uint8_t disc_key_pack_data[28668];
};
struct scsi_read_dvd_struct_data_dds
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	uint8_t dds_info[2048];
};

struct scsi_read_dvd_struct_data_medium_status
{
	uint8_t data_len[2];
	uint8_t reserved0[2];
	uint8_t byte4;
#define RDSD_MS_CARTRIDGE	0x80
#define RDSD_MS_OUT		0x40
#define RDSD_MS_MSWI		0x08
#define RDSD_MS_CWP		0x04
#define RDSD_MS_PWP		0x02
	uint8_t disc_type_id;
#define RDSD_DT_NEED_CARTRIDGE	0x00
#define RDSD_DT_NO_CART_NEEDED	0x01
	uint8_t reserved1;
	uint8_t ram_swi_info;
#define RDSD_SWI_NO_BARE	0x01
#define RDSD_SWI_UNSPEC		0xff
};

struct scsi_read_dvd_struct_data_spare_area
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	uint8_t unused_primary[4];
	uint8_t unused_supl[4];
	uint8_t allocated_supl[4];
};

struct scsi_read_dvd_struct_data_rmd_borderout
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	uint8_t rmd[30720]; 	/* maximum is 30720 bytes */
};

struct scsi_read_dvd_struct_data_rmd
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	uint8_t last_sector_num[4];
	uint8_t rmd_bytes[32768];  /* This is the maximum */
};

/*
 * XXX KDM this is the MMC2 version of the structure.
 * The variable positions have changed (in a semi-conflicting way) in the
 * MMC3 spec, although the overall length of the structure is the same.
 */
struct scsi_read_dvd_struct_data_leadin
{
	uint8_t data_len[2];
	uint8_t reserved0[2];
	uint8_t field_id_1;
	uint8_t app_code;
	uint8_t disc_physical_data;
	uint8_t last_addr[3];
	uint8_t reserved1[2];
	uint8_t field_id_2;
	uint8_t rwp;
	uint8_t rwp_wavelength;
	uint8_t optimum_write_strategy;
	uint8_t reserved2[4];
	uint8_t field_id_3;
	uint8_t manuf_id_17_12[6];
	uint8_t reserved3;
	uint8_t field_id_4;
	uint8_t manuf_id_11_6[6];
	uint8_t reserved4;
	uint8_t field_id_5;
	uint8_t manuf_id_5_0[6];
	uint8_t reserved5[25];
};

struct scsi_read_dvd_struct_data_disc_id
{
	uint8_t data_len[2];
	uint8_t reserved[4];
	uint8_t random_num[2];
	uint8_t year[4];
	uint8_t month[2];
	uint8_t day[2];
	uint8_t hour[2];
	uint8_t minute[2];
	uint8_t second[2];
};

struct scsi_read_dvd_struct_data_generic_dcb
{
	uint8_t content_desc[4];
#define SCSI_RCB
	uint8_t unknown_desc_actions[4];
#define RDSD_ACTION_RECORDING	0x0001
#define RDSD_ACTION_READING	0x0002
#define RDSD_ACTION_FORMAT	0x0004
#define RDSD_ACTION_MODIFY_DCB	0x0008
	uint8_t vendor_id[32];
	uint8_t dcb_data[32728];
};

struct scsi_read_dvd_struct_data_dcb
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	struct scsi_read_dvd_struct_data_generic_dcb dcb;
};

struct read_dvd_struct_write_prot
{
	uint8_t data_len[2];
	uint8_t reserved0[2];
	uint8_t write_prot_status;
#define RDSD_WPS_MSWI		0x08
#define RDSD_WPS_CWP		0x04
#define RDSD_WPS_PWP		0x02
#define RDSD_WPS_SWPP		0x01
	uint8_t reserved[3];
};

struct read_dvd_struct_list_entry
{
	uint8_t format_code;
	uint8_t sds_rds;
#define RDSD_SDS_NOT_WRITEABLE	0x00
#define RDSD_SDS_WRITEABLE	0x80
#define RDSD_SDS_MASK		0x80
#define RDSD_RDS_NOT_READABLE	0x00
#define RDSD_RDS_READABLE	0x40
#define RDSD_RDS_MASK		0x40
	uint8_t struct_len[2];
};

struct read_dvd_struct_data_list
{
	uint8_t data_len[2];
	uint8_t reserved[2];
	struct read_dvd_struct_list_entry entries[0];
};

struct scsi_read_cd_cap_data
{
	uint8_t addr_3;	/* Most significant */
	uint8_t addr_2;
	uint8_t addr_1;
	uint8_t addr_0;	/* Least significant */
	uint8_t length_3;	/* Most significant */
	uint8_t length_2;
	uint8_t length_1;
	uint8_t length_0;	/* Least significant */
};

struct cd_audio_page
{
	uint8_t page_code;
#define	CD_PAGE_CODE		0x3F
#define	AUDIO_PAGE		0x0e
#define	CD_PAGE_PS		0x80
	uint8_t param_len;
	uint8_t flags;
#define	CD_PA_SOTC		0x02
#define	CD_PA_IMMED		0x04
	uint8_t unused[2];
	uint8_t format_lba;
#define	CD_PA_FORMAT_LBA	0x0F
#define	CD_PA_APR_VALID		0x80
	uint8_t lb_per_sec[2];
	struct	port_control
	{
		uint8_t channels;
#define	CHANNEL			0x0F
#define	CHANNEL_0		1
#define	CHANNEL_1		2
#define	CHANNEL_2		4
#define	CHANNEL_3		8
#define	LEFT_CHANNEL		CHANNEL_0
#define	RIGHT_CHANNEL		CHANNEL_1
		uint8_t volume;
	} port[4];
#define	LEFT_PORT		0
#define	RIGHT_PORT		1
};

struct scsi_cddvd_capabilities_page_sd {
	uint8_t reserved;
	uint8_t rotation_control;
	uint8_t write_speed_supported[2];
};

struct scsi_cddvd_capabilities_page {
	uint8_t page_code;
#define	SMS_CDDVD_CAPS_PAGE		0x2a
	uint8_t page_length;
	uint8_t caps1;
	uint8_t caps2;
	uint8_t caps3;
	uint8_t caps4;
	uint8_t caps5;
	uint8_t caps6;
	uint8_t obsolete[2];
	uint8_t nvol_levels[2];
	uint8_t buffer_size[2];
	uint8_t obsolete2[2];
	uint8_t reserved;
	uint8_t digital;
	uint8_t obsolete3;
	uint8_t copy_management;
	uint8_t reserved2;
	uint8_t rotation_control;
	uint8_t cur_write_speed;
	uint8_t num_speed_descr;
	struct scsi_cddvd_capabilities_page_sd speed_descr[];
};

union cd_pages
{
	struct cd_audio_page audio;
};

struct cd_mode_data_10
{
	struct scsi_mode_header_10 header;
	struct scsi_mode_blk_desc  blk_desc;
	union cd_pages page;
};

struct cd_mode_data
{
	struct scsi_mode_header_6 header;
	struct scsi_mode_blk_desc blk_desc;
	union cd_pages page;
};

union cd_mode_data_6_10
{
	struct cd_mode_data mode_data_6;
	struct cd_mode_data_10 mode_data_10;
};

struct cd_mode_params
{
	STAILQ_ENTRY(cd_mode_params)	links;
	int				cdb_size;
	int				alloc_len;
	uint8_t			*mode_buf;
};

__BEGIN_DECLS
void scsi_report_key(struct ccb_scsiio *csio, uint32_t retries,
		     void (*cbfcnp)(struct cam_periph *, union ccb *),
		     uint8_t tag_action, uint32_t lba, uint8_t agid,
		     uint8_t key_format, uint8_t *data_ptr,
		     uint32_t dxfer_len, uint8_t sense_len,
		     uint32_t timeout);

void scsi_send_key(struct ccb_scsiio *csio, uint32_t retries,
		   void (*cbfcnp)(struct cam_periph *, union ccb *),
		   uint8_t tag_action, uint8_t agid, uint8_t key_format,
		   uint8_t *data_ptr, uint32_t dxfer_len, uint8_t sense_len,
		   uint32_t timeout);

void scsi_read_dvd_structure(struct ccb_scsiio *csio, uint32_t retries,
			     void (*cbfcnp)(struct cam_periph *, union ccb *),
			     uint8_t tag_action, uint32_t address,
			     uint8_t layer_number, uint8_t format,
			     uint8_t agid, uint8_t *data_ptr,
			     uint32_t dxfer_len, uint8_t sense_len,
			     uint32_t timeout);

void scsi_read_toc(struct ccb_scsiio *csio, uint32_t retries,
		   void (*cbfcnp)(struct cam_periph *, union ccb *),
		   uint8_t tag_action, uint8_t byte1_flags, uint8_t format,
		   uint8_t track, uint8_t *data_ptr, uint32_t dxfer_len,
		   int sense_len, int timeout);

__END_DECLS

#endif /*_SCSI_SCSI_CD_H*/