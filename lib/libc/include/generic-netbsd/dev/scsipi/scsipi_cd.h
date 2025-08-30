/*	$NetBSD: scsipi_cd.h,v 1.21 2009/04/01 12:19:04 reinoud Exp $	*/

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
 */

/*
 *	Define two bits always in the same place in byte 2 (flag byte)
 */
#define	CD_RELADDR	0x01
#define	CD_MSF		0x02

/*
 * SCSI and SCSI-like command format
 */

#define	LOAD_UNLOAD	0xa6
struct scsipi_load_unload {
	u_int8_t opcode;
	u_int8_t unused1[3];
	u_int8_t options;
	u_int8_t unused2[3];
	u_int8_t slot;
	u_int8_t unused3[3];
} __packed;

#define PAUSE			0x4b	/* cdrom pause in 'play audio' mode */
struct scsipi_pause {
	u_int8_t opcode;
	u_int8_t byte2;
	u_int8_t unused[6];
	u_int8_t resume;
	u_int8_t control;
} __packed;
#define	PA_PAUSE	0x00
#define PA_RESUME	0x01

#define PLAY_MSF		0x47	/* cdrom play Min,Sec,Frames mode */
struct scsipi_play_msf {
	u_int8_t opcode;
	u_int8_t byte2;
	u_int8_t unused;
	u_int8_t start_m;
	u_int8_t start_s;
	u_int8_t start_f;
	u_int8_t end_m;
	u_int8_t end_s;
	u_int8_t end_f;
	u_int8_t control;
} __packed;

#define PLAY			0x45	/* cdrom play  'play audio' mode */
struct scsipi_play {
	u_int8_t opcode;
	u_int8_t byte2;
	u_int8_t blk_addr[4];
	u_int8_t unused;
	u_int8_t xfer_len[2];
	u_int8_t control;
} __packed;

#define READ_HEADER		0x44	/* cdrom read header */
struct scsipi_read_header {
	u_int8_t opcode;
	u_int8_t byte2;
	u_int8_t blk_addr[4];
	u_int8_t unused;
	u_int8_t data_len[2];
	u_int8_t control;
} __packed;

#define READ_SUBCHANNEL		0x42	/* cdrom read Subchannel */
struct scsipi_read_subchannel {
	u_int8_t opcode;
	u_int8_t byte2;
	u_int8_t byte3;
#define	SRS_SUBQ	0x40
	u_int8_t subchan_format;
	u_int8_t unused[2];
	u_int8_t track;
	u_int8_t data_len[2];
	u_int8_t control;
} __packed;

#define READ_TOC		0x43	/* cdrom read TOC */
struct scsipi_read_toc {
	u_int8_t opcode;
	u_int8_t addr_mode;
	u_int8_t resp_format;
	u_int8_t unused[3];
	u_int8_t from_track;		/* session nr in format 2 */
	u_int8_t data_len[2];
	u_int8_t control;
} __packed;

struct scsipi_toc_header {
	uint8_t	 length[2];
	uint8_t  first;			/* track or session */
	uint8_t  last;
} __packed;

/* read TOC form 0 result entries */
struct scsipi_toc_formatted {
	uint8_t  unused1;
	uint8_t  adrcontrol;
	uint8_t  tracknr;
	uint8_t  unused2;
	uint8_t	 msf_lba[4];		/* union msf_lba from cdio.h */
} __packed;

/* read TOC form 1 result entries */
struct scsipi_toc_msinfo {
	uint8_t  unused1;
	uint8_t  adrcontol;
	uint8_t  tracknr;		/* first track last compl. session */
	uint8_t  unused2;
	uint8_t	 msf_lba[4];		/* union msf_lba from cdio.h */
} __packed;

/* read TOC form 2 result entries */
struct scsipi_toc_rawtoc {
	uint8_t  sessionnr;
	uint8_t  adrcontrol;
	uint8_t  tno;
	uint8_t  point;
	uint8_t  min;
	uint8_t  sec;
	uint8_t  frame;
	uint8_t  zero;			/* zero/unused */
	uint8_t  pmin;
	uint8_t  psec;
	uint8_t  pframe;
} __packed;

/* read TOC form 3, 4 and 5 obmitted yet */

#define GET_CONFIGURATION	0x46	/* Get configuration */
#define GET_CONF_NO_FEATURES_LEN 8
struct scsipi_get_configuration {
	uint8_t  opcode;
	uint8_t  request_type;
	uint8_t  start_at_feature[2];
	uint8_t  unused[3];
	uint8_t  data_len[2];
	uint8_t  control;
} __packed;

struct scsipi_get_conf_data {
	uint8_t  data_len[4];
	uint8_t  unused[2];
	uint8_t  mmc_profile[2];	/* current mmc profile for disk */
	uint8_t  feature_desc[1];	/* feature descriptors follow	*/
} __packed;

struct scsipi_get_conf_feature {	/* feature descriptor */
	uint8_t  featurecode[2];
	uint8_t  flags;
	uint8_t  additional_length;	/* length of feature dependent  */
	uint8_t  feature_dependent[256];
} __packed;
#define FEATUREFLAG_CURRENT    1
#define FEATUREFLAG_PERSISTENT 2


#define READ_DISCINFO 0x51
struct scsipi_read_discinfo {
	uint8_t  opcode;
	uint8_t  unused[6];
	uint8_t  data_len[2];
	uint8_t  control;
} __packed;

#define READ_DISCINFO_SMALLSIZE  12
#define READ_DISCINFO_BIGSIZE    34	/* + entries */
struct scsipi_read_discinfo_data {
	uint8_t  data_len[2];
	uint8_t  disc_state;
	uint8_t  first_track;
	uint8_t  num_sessions_lsb;
	uint8_t  first_track_last_session_lsb;
	uint8_t  last_track_last_session_lsb;
	uint8_t  disc_state2;
	uint8_t  disc_type;
	uint8_t  num_sessions_msb;
	uint8_t  first_track_last_session_msb;
	uint8_t  last_track_last_session_msb;
	uint8_t  discid[4];
	uint8_t  last_session_leadin_hmsf[4];
	uint8_t  last_possible_start_leadout_hmsf[4];
	uint8_t  disc_bar_code[8];
	uint8_t  application_code;
	uint8_t  num_opc_table_entries;
	uint8_t  opc_table_entries[1];	/* opc table entries follow	*/
} __packed;


#define READ_TRACKINFO 0x52
struct scsipi_read_trackinfo {
	uint8_t  opcode;
	uint8_t  addr_type;
	uint8_t  address[4];
	uint8_t  nothing;
	uint8_t  data_len[2];
	uint8_t  control;
} __packed;
#define READ_TRACKINFO_ADDR_LBA    0
#define READ_TRACKINFO_ADDR_TRACK  1
#define READ_TRACKINFO_ADDR_SESS   2

struct scsipi_read_trackinfo_data {
	uint8_t  data_len[2];
	uint8_t  track_lsb;
	uint8_t  session_lsb;
	uint8_t  unused1;
	uint8_t  track_info_1;
	uint8_t  track_info_2;
	uint8_t  data_valid;
	uint8_t  track_start[4];
	uint8_t  next_writable[4];
	uint8_t  free_blocks[4];
	uint8_t  packet_size[4];
	uint8_t  track_size[4];
	uint8_t  last_recorded[4];
	uint8_t  track_msb;
	uint8_t  session_msb;
	uint8_t  unused2[2];
} __packed;
#define READ_TRACKINFO_RETURNSIZE 36


#define CLOSE_TRACKSESSION 0x5B
struct scsipi_close_tracksession {
	uint8_t  opcode;
	uint8_t  addr_type;		/* bit 1 holds immediate */
	uint8_t  function;		/* bits 2,1,0 */
	uint8_t  unused1;
	uint8_t  tracksessionnr[2];
	uint8_t  unused2[3];
	uint8_t  control;
} __packed;


#define RESERVE_TRACK 0x53
struct scsipi_reserve_track {
	uint8_t  opcode;
	uint8_t  reserved[4];
	uint8_t  reservation_size[4];
	uint8_t  control;
} __packed;


#define REPAIR_TRACK 0x58
struct scsipi_repair_track {
	uint8_t  opcode;
	uint8_t  reserved1;		/* bit 1 holds immediate */
	uint8_t  reserved2[2];
	uint8_t  tracknr[2];		/* logical track nr */
	uint8_t  reserved3[3];
	uint8_t  control;
} __packed;


#define READ_CD_CAPACITY	0x25	/* slightly different from disk */
struct scsipi_read_cd_capacity {
	u_int8_t opcode;
	u_int8_t byte2;
	u_int8_t addr[4];
	u_int8_t unused[3];
	u_int8_t control;
} __packed;

struct scsipi_read_cd_cap_data {
	u_int8_t addr[4];
	u_int8_t length[4];
} __packed;


/* mod pages common to scsi and atapi */
struct cd_audio_page {
	u_int8_t pg_code;
#define		AUDIO_PAGE	0x0e
	u_int8_t pg_length;
	u_int8_t flags;
#define		CD_PA_SOTC	0x02
#define		CD_PA_IMMED	0x04
	u_int8_t unused[2];
	u_int8_t format_lba; /* valid only for SCSI CDs */
#define		CD_PA_FORMAT_LBA 0x0F
#define		CD_PA_APR_VALID	0x80
	u_int8_t lb_per_sec[2];
	struct port_control {
		u_int8_t channels;
#define	CHANNEL 0x0F
#define	CHANNEL_0 1
#define	CHANNEL_1 2
#define	CHANNEL_2 4
#define	CHANNEL_3 8
#define		LEFT_CHANNEL	CHANNEL_0
#define		RIGHT_CHANNEL	CHANNEL_1
#define		MUTE_CHANNEL	0x0
#define		BOTH_CHANNEL	LEFT_CHANNEL | RIGHT_CHANNEL
		u_int8_t volume;
	} port[4];
#define	LEFT_PORT	0
#define	RIGHT_PORT	1
};