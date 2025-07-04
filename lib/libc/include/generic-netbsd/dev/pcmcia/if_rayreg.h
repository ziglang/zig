/*	$NetBSD: if_rayreg.h,v 1.12 2022/05/22 11:27:35 andvar Exp $	*/
/*
 * Copyright (c) 2000 Christian E. Hopps
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
 * 3. Neither the name of the author nor the names of any co-contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
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
 */

#include <sys/ioccom.h>

#define	RAY_MAXSSIDLEN	32

/*
 * CCR registers
 */
#define RAY_COR		0	/* config option register */
#define	RAY_CCSR	1	/* card config and status register */
#define	RAY_PIN		2	/* not in hw */
#define	RAY_SOCKETCOPY	3	/* not used by hw */
#define	RAY_HCSIR	5	/* HCS intr register */
#define	RAY_ECFIR	6	/* ECF intr register */
#define	RAY_AR0		8	/* authorization register 0 (unused) */
#define	RAY_AR1		9	/* authorization register 1 (unused) */
#define	RAY_PMR		10	/* program mode register (unused) */
#define	RAY_TMR		11	/* pc test mode register (unused) */
#define	RAY_FCWR	16	/* frequency control word register */

/*
 * XXX these registers cannot be accessed with pcmcia.c's 0x14 byte mapping
 * of the CCR for us
 */
#if 0
#define RAY_TMC1	0x014	/* test mode control 1 (unused) */
#define RAY_TMC2	0x015	/* test mode control 1 (unused) */
#define RAY_TMC3	0x016	/* test mode control 1 (unused) */
#define RAY_TMC4	0x017	/* test mode control 1 (unused) */
#endif

/*
 * COR register bits
 */
#define	RAY_COR_CFG_NUM		0x01	/* currently ignored and set */
#define RAY_COR_CFG_MASK	0x3f	/* mask for function */
#define	RAY_COR_LEVEL_IRQ	0x40	/* currently ignored and set */
#define	RAY_COR_RESET		0x80	/* soft-reset the card */

/*
 * CCS register bits
 */
/* XXX the linux driver indicates bit 0 is the irq bit */
#define	RAY_CCS_IRQ		0x02	/* interrupt pending */
#define	RAY_CCS_POWER_DOWN	0x04

/*
 * HCSI register bits
 *
 * the host can only clear this bit.
 */
#define	RAY_HCSIR_IRQ		0x01	/* indicates an interrupt */

/*
 * ECFI register values
 */
#define	RAY_ECSIR_IRQ		0x01	/* interrupt the card */

/*
 * authorization register 0 values
 *    -- used for testing/programming the card (unused)
 */
#define	RAY_AR0_ON		0x57

/*
 * authorization register 1 values
 *	-- used for testing/programming the card (unused)
 */
#define	RAY_AR1_ON		0x82

/*
 * PMR bits -- these are used to program the card (unused)
 */
#define	RAY_PMR_PC2PM		0x02	/* grant access to firmware flash */
#define	RAY_PMR_PC2CAL		0x10	/* read access to the A/D modem inp */
#define	RAY_PMR_MLSE		0x20	/* read access to the MSLE prom */

/*
 * TMR bits -- get access to test modes (unused)
 */
#define	RAY_TMR_TEST		0x08	/* test mode */

/*
 * FCWR -- frequency control word, values from [0x02,0xA6] map to
 * RF frequency values.
 */

/*
 * 48k of memory -- would like to map this into smaller isa windows
 * but doesn't seem currently possible with the pcmcia code
 */
#define	RAY_SRAM_MEM_BASE	0
#define	RAY_SRAM_MEM_SIZE	0xc000

/*
 * offsets into shared ram
 */
#define	RAY_SCB_BASE		0x0	/* cfg/status/ctl area */
#define	RAY_STATUS_BASE		0x0100
#define	RAY_HOST_TO_ECF_BASE	0x0200
#define	RAY_ECF_TO_HOST_BASE	0x0300
#define	RAY_CCS_BASE		0x0400
#define	RAY_RCS_BASE		0x0800
#define	RAY_APOINT_TIM_BASE	0x0c00
#define	RAY_SSID_LIST_BASE	0x0d00
#define	RAY_TX_BASE		0x1000
#define	RAY_TX_SIZE		0x7000
#define	RAY_TX_END		0x8000
#define	RAY_RX_BASE		0x8000
#define	RAY_RX_END		0xc000
#define	RAY_RX_MASK		0x3fff

struct ray_ecf_startup {
	u_int8_t	e_status;		/* RAY_ECFS_ */
	u_int8_t	e_station_addr[ETHER_ADDR_LEN];
	u_int8_t	e_resv0;
	u_int8_t	e_rates[8];
	u_int8_t	e_japan_callsign[12];
	u_int8_t	e_prg_cksum;
	u_int8_t	e_cis_cksum;
	u_int8_t	e_fw_build_string;
	u_int8_t	e_fw_build;
	u_int8_t	e_fw_resv;
	u_int8_t	e_asic_version;
	u_int8_t	e_tib_size;
	u_int8_t	e_resv1[29];
};

#define	RAY_ECFS_RESERVED0		0x01
#define	RAY_ECFS_PROC_SELF_TEST		0x02
#define	RAY_ECFS_PROG_MEM_CHECKSUM	0x04
#define	RAY_ECFS_DATA_MEM_TEST		0x08
#define	RAY_ECFS_RX_CALIBRATION		0x10
#define	RAY_ECFS_FW_VERSION_COMPAT	0x20
#define	RAY_ECFS_RERSERVED1		0x40
#define	RAY_ECFS_TEST_COMPLETE		0x80
#define	RAY_ECFS_CARD_OK		RAY_ECFS_TEST_COMPLETE

/* configure/status/control memory */
struct ray_csc {
	u_int8_t	csc_mrxo_own;	/* 0 ECF writes, 1 host write */
	u_int8_t	csc_mrxc_own;	/* " */
	u_int8_t	csc_rxhc_own;	/* " */
	u_int8_t	csc_resv;
	u_int16_t	csc_mrx_overflow;	/* ECF incs on rx overflow */
	u_int16_t	csc_mrx_cksum;	/* " on cksum error */
	u_int16_t	csc_rx_hcksum;	/* " on header cksum error */
	u_int8_t	csc_rx_noise;		/* average RSL measurement */
};

/* status area */
struct ray_status {
	u_int8_t	st_startup_word;
	u_int8_t	st_station_addr[ETHER_ADDR_LEN];
	u_int8_t	st_calc_prog_cksum;
	u_int8_t	st_calc_cis_cksum;
	u_int8_t	st_ecf_spare[7];
	u_int8_t	st_japan_callsign[12];
};

/*
 * Host to ECF data formats
 */
struct ray_startup_params_head {
	u_int8_t	sp_net_type;	/* 0: ad-hoc 1: infra */
	u_int8_t	sp_ap_status;	/* 0: terminal 1: access-point */
	u_int8_t	sp_ssid[RAY_MAXSSIDLEN];	/* current SSID */
	u_int8_t	sp_scan_mode;	/* 1: active */
	u_int8_t	sp_apm_mode;	/* 0: none 1: power-saving */
	u_int8_t	sp_mac_addr[ETHER_ADDR_LEN];
	u_int8_t	sp_frag_thresh[2];
/*2c*/	u_int8_t	sp_dwell_time[2];
/*2e*/	u_int8_t	sp_beacon_period[2];
/*30*/	u_int8_t	sp_dtim_interval;
/*31*/	u_int8_t	sp_max_retry;	/* number of times to attempt tx */
/*32*/	u_int8_t	sp_ack_timo;
/*33*/	u_int8_t	sp_sifs;
/*34*/	u_int8_t	sp_difs;
/*35*/	u_int8_t	sp_pifs;
/*36*/	u_int8_t	sp_rts_thresh[2];
/*38*/	u_int8_t	sp_scan_dwell[2];
/*3a*/	u_int8_t	sp_scan_max_dwell[2];
/*3c*/	u_int8_t	sp_assoc_timo;
/*3d*/	u_int8_t	sp_adhoc_scan_cycle;
/*3e*/	u_int8_t	sp_infra_scan_cycle;
/*3f*/	u_int8_t	sp_infra_super_scan_cycle;
/*40*/	u_int8_t	sp_promisc;
/*41*/	u_int8_t	sp_uniq_word[2];
/*43*/	u_int8_t	sp_slot_time;
/*44*/	u_int8_t	sp_roam_low_snr_thresh;	/* if below this inc count */

/*45*/	u_int8_t	sp_low_snr_count;	/* roam after cnt below thrsh */
/*46*/	u_int8_t	sp_infra_missed_beacon_count;
/*47*/	u_int8_t	sp_adhoc_missed_beacon_count;

/*48*/	u_int8_t	sp_country_code;
/*49*/	u_int8_t	sp_hop_seq;
/*4a*/	u_int8_t	sp_hop_seq_len;	/* no longer supported */
} __packed;

/* build 5 tail to the startup params */
struct ray_startup_params_tail_5 {
	u_int8_t	sp_cw_max[2];
	u_int8_t	sp_cw_min[2];
	u_int8_t	sp_noise_filter_gain;
	u_int8_t	sp_noise_limit_offset;
	u_int8_t	sp_rssi_thresh_offset;
	u_int8_t	sp_busy_thresh_offset;
	u_int8_t	sp_sync_thresh;
	u_int8_t	sp_test_mode;
	u_int8_t	sp_test_min_chan;
	u_int8_t	sp_test_max_chan;
	u_int8_t	sp_allow_probe_resp;
	u_int8_t	sp_privacy_must_start;
	u_int8_t	sp_privacy_can_join;
	u_int8_t	sp_basic_rate_set[8];
} __packed;

/* build 4 (webgear) tail to the startup params */
struct ray_startup_params_tail_4 {
/*4b*/	u_int8_t	sp_cw_max;		/* 2 bytes in build 5 */
/*4c*/	u_int8_t	sp_cw_min;		/* 2 bytes in build 5 */
/*4e*/	u_int8_t	sp_noise_filter_gain;
/*4f*/	u_int8_t	sp_noise_limit_offset;
	u_int8_t	sp_rssi_thresh_offset;
	u_int8_t	sp_busy_thresh_offset;
	u_int8_t	sp_sync_thresh;
	u_int8_t	sp_test_mode;
	u_int8_t	sp_test_min_chan;
	u_int8_t	sp_test_max_chan;
	/* more bytes in build 5 */
} __packed;

/*
 * Parameter IDs for the update/report param commands and values if
 * relevant
 */
#define	RAY_PID_NET_TYPE		0
#define	RAY_PID_AP_STATUS		1
#define	RAY_PID_SSID			2
#define RAY_PID_SCAN_MODE		3
#define	RAY_PID_APM_MODE		4
#define	RAY_PID_MAC_ADDR		5
#define	RAY_PID_FRAG_THRESH		6
#define	RAY_PID_DWELL_TIME		7
#define	RAY_PID_BEACON_PERIOD		8
#define	RAY_PID_DTIM_INT		9
#define	RAY_PID_MAX_RETRY		10
#define	RAY_PID_ACK_TIMO		11
#define	RAY_PID_SIFS			12
#define	RAY_PID_DIFS			13
#define	RAY_PID_PIFS			14
#define	RAY_PID_RTS_THRESH		15
#define	RAY_PID_SCAN_DWELL_PERIOD	16
#define	RAY_PID_MAX_SCAN_DWELL_PERIOD	17
#define	RAY_PID_ASSOC_TIMO		18
#define	RAY_PID_ADHOC_SCAN_CYCLE	19
#define	RAY_PID_INFRA_SCAN_CYCLE	20
#define	RAY_PID_INFRA_SUPER_SCAN_CYCLE	21
#define	RAY_PID_PROMISC			22
#define	RAY_PID_UNIQ_WORD		23
#define	RAY_PID_SLOT_TIME		24
#define	RAY_PID_ROAM_LOW_SNR_THRESH	25
#define	RAY_PID_LOW_SNR_COUNT		26
#define	RAY_PID_INFRA_MISSED_BEACON_COUNT	27
#define	RAY_PID_ADHOC_MISSED_BEACON_COUNT	28
#define	RAY_PID_COUNTRY_CODE		29
#define	RAY_PID_HOP_SEQ			30
#define	RAY_PID_HOP_SEQ_LEN		31
#define	RAY_PID_CW_MAX			32
#define	RAY_PID_CW_MIN			33
#define	RAY_PID_NOISE_FILTER_GAIN	34
#define	RAY_PID_NOISE_LIMIT_OFFSET	35
#define	RAY_PID_RSSI_THRESH_OFFSET	36
#define	RAY_PID_BUSY_THRESH_OFFSET	37
#define	RAY_PID_SYNC_THRESH		38
#define	RAY_PID_TEST_MODE		39
#define	RAY_PID_TEST_MIN_CHAN		40
#define	RAY_PID_TEST_MAX_CHAN		41
#define	RAY_PID_ALLOW_PROBE_RESP	42
#define	RAY_PID_PRIVACY_MUST_START	43
#define	RAY_PID_PRIVACY_CAN_JOIN	44
#define	RAY_PID_BASIC_RATE_SET		45
#define	RAY_PID_MAX			46

/*
 * various values for the above parameters
 */
#define	RAY_PID_NET_TYPE_ADHOC		0x00
#define	RAY_PID_NET_TYPE_INFRA		0x01

#define	RAY_PID_AP_STATUS_TERMINAL	0x00	/* not access-point */
#define	RAY_PID_AP_STATUS_AP		0x01	/* act as access-point */

#define	RAY_PID_SCAN_MODE_PASSIVE	0x00	/* hw doesn't implement */
#define	RAY_PID_SCAN_MODE_ACTIVE	0x01

#define	RAY_PID_APM_MODE_NONE		0x00	/* no power saving */
#define	RAY_PID_APM_MODE_PS		0x01	/* power saving mode */

#define	RAY_PID_COUNTRY_CODE_USA	0x1
#define	RAY_PID_COUNTRY_CODE_EUROPE	0x2
#define	RAY_PID_COUNTRY_CODE_JAPAN	0x3
#define	RAY_PID_COUNTRY_CODE_KOREA	0x4
#define	RAY_PID_COUNTRY_CODE_SPAIN	0x5
#define	RAY_PID_COUNTRY_CODE_FRANCE	0x6
#define	RAY_PID_COUNTRY_CODE_ISRAEL	0x7
#define	RAY_PID_COUNTRY_CODE_AUSTRALIA	0x8
#define	RAY_PID_COUNTRY_CODE_JAPAN_TEST	0x9
#define	RAY_PID_COUNTRY_CODE_MAX	0xa

#define	RAY_PID_TEST_MODE_NORMAL	0x0
#define	RAY_PID_TEST_MODE_ANT_1		0x1
#define	RAY_PID_TEST_MODE_ATN_2		0x2
#define	RAY_PID_TEST_MODE_ATN_BOTH	0x3

#define	RAY_PID_ALLOW_PROBE_RESP_DISALLOW	0x0
#define	RAY_PID_ALLOW_PROBE_RESP_ALLOW		0x1

#define	RAY_PID_PRIVACY_MUST_START_NOWEP	0x0
#define	RAY_PID_PRIVACY_MUST_START_WEP		0x1

#define	RAY_PID_PRIVACY_CAN_JOIN_NOWEP		0x0
#define	RAY_PID_PRIVACY_CAN_JOIN_WEP		0x1
#define	RAY_PID_PRIVACY_CAN_JOIN_DONT_CARE	0x2

#define	RAY_PID_BASIC_RATE_500K		1
#define	RAY_PID_BASIC_RATE_1000K	2
#define	RAY_PID_BASIC_RATE_1500K	3
#define	RAY_PID_BASIC_RATE_2000K	4

/*
 * System Control Block
 */
#define	RAY_SCB_CCSI		0x00	/* host CCS index */
#define	RAY_SCB_RCCSI		0x01	/* ecf RCCS index */

/*
 * command control structures (for CCSR commands)
 */

/*
 * commands for CCSR
 */
#define	RAY_CMD_START_PARAMS	0x01	/* download start params */
#define	RAY_CMD_UPDATE_PARAMS	0x02	/* update params */
#define	RAY_CMD_REPORT_PARAMS	0x03	/* report params */
#define	RAY_CMD_UPDATE_MCAST	0x04	/* update mcast list */
#define	RAY_CMD_UPDATE_APM	0x05	/* update power saving mode */
#define	RAY_CMD_START_NET	0x06
#define	RAY_CMD_JOIN_NET	0x07
#define	RAY_CMD_START_ASSOC	0x08
#define	RAY_CMD_TX_REQ		0x09
#define	RAY_CMD_TEST_MEM	0x0a
#define	RAY_CMD_SHUTDOWN	0x0b
#define	RAY_CMD_DUMP_MEM	0x0c
#define	RAY_CMD_START_TIMER	0x0d
#define	RAY_CMD_MAX		0x0e

/*
 * unsolicited commands from the ECF
 */
#define	RAY_ECMD_RX_DONE		0x80	/* process rx packet */
#define	RAY_ECMD_REJOIN_DONE		0x81	/* rejoined the network */
#define	RAY_ECMD_ROAM_START		0x82	/* roaming started */
#define	RAY_ECMD_JAPAN_CALL_SIGNAL	0x83	/* japan test thing */


#define	RAY_CCS_LINK_NULL	0xff
#define	RAY_CCS_SIZE	16

#define	RAY_CCS_TX_FIRST	0
#define	RAY_CCS_TX_LAST		13
#define	RAY_CCS_NTX		(RAY_CCS_TX_LAST - RAY_CCS_TX_FIRST + 1)
#define	RAY_TX_BUF_SIZE		2048
#define	RAY_CCS_CMD_FIRST	14
#define	RAY_CCS_CMD_LAST	63
#define	RAY_CCS_NCMD		(RAY_CCS_CMD_LAST - RAY_CCS_CMD_FIRST + 1)
#define	RAY_CCS_LAST		63

#define	RAY_RCCS_FIRST	64
#define	RAY_RCCS_LAST	127

struct ray_cmd {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
};

#define	RAY_CCS_STATUS_FREE		0x0
#define	RAY_CCS_STATUS_BUSY		0x1
#define	RAY_CCS_STATUS_COMPLETE		0x2
#define	RAY_CCS_STATUS_FAIL		0x3

/* RAY_CMD_UPDATE_PARAMS */
struct ray_cmd_update {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_paramid;
	u_int8_t	c_nparam;
	u_int8_t	c_failcause;
};

/* RAY_CMD_REPORT_PARAMS */
struct ray_cmd_report {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_paramid;
	u_int8_t	c_nparam;
	u_int8_t	c_failcause;
	u_int8_t	c_len;
};

/* RAY_CMD_UPDATE_MCAST */
struct ray_cmd_update_mcast {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_nmcast;
};

/* RAY_CMD_UPDATE_APM */
struct ray_cmd_udpate_apm {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_mode;
};

/* RAY_CMD_START_NET and RAY_CMD_JOIN_NET */
struct ray_cmd_net {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_upd_param;
	u_int8_t	c_bss_id[ETHER_ADDR_LEN];
	u_int8_t	c_inited;
	u_int8_t	c_def_txrate;
	u_int8_t	c_encrypt;
};

/* parameters passwd in h2e section when c_upd_param is set in ray_cmd_net */
struct ray_net_params {
	u_int8_t	p_net_type;
	u_int8_t	p_ssid[32];
	u_int8_t	p_privacy_must_start;
	u_int8_t	p_privacy_can_join;
};

/* RAY_CMD_UPDATE_ASSOC */
struct ray_cmd_update_assoc {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_astatus;
	u_int8_t	c_aid[2];
};

/* RAY_CMD_TX_REQ */
struct ray_cmd_tx {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_bufp[2];
	u_int8_t	c_len[2];
	u_int8_t	c_resv[5];
	u_int8_t	c_tx_rate;
	u_int8_t	c_apm_mode;
	u_int8_t	c_nretry;
	u_int8_t	c_antenna;
};

/* RAY_CMD_TX_REQ (for build 4) */
struct ray_cmd_tx_4 {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_bufp[2];
	u_int8_t	c_len[2];
	u_int8_t	c_addr[ETHER_ADDR_LEN];
	u_int8_t	c_apm_mode;
	u_int8_t	c_nretry;
	u_int8_t	c_antenna;
};

/* RAY_CMD_DUMP_MEM */
struct ray_cmd_dump_mem {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_memtype;
	u_int8_t	c_memp[2];
	u_int8_t	c_len;
};

/* RAY_CMD_START_TIMER */
struct ray_cmd_start_timer {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_duration[2];
};

struct ray_cmd_rx {
	u_int8_t	c_status;		/* ccs generic header */
	u_int8_t	c_cmd;			/* " */
	u_int8_t	c_link;			/* " */
	u_int8_t	c_bufp[2];	/* buffer pointer */
	u_int8_t	c_len[2];	/* length */
	u_int8_t	c_siglev;	/* signal level */
	u_int8_t	c_nextfrag;	/* next fragment in packet */
	u_int8_t	c_pktlen[2];	/* total packet length */
	u_int8_t	c_antenna;	/* antenna with best reception */
	u_int8_t	c_updbss;	/* only 1 for beacon messages */
};

#define	RAY_TX_PHY_SIZE	0x4

/* this is used by the user to request objects */
struct ray_param_req {
	int		r_failcause;
	u_int8_t	r_paramid;
	u_int8_t	r_len;
	u_int8_t	r_data[256];
};
#define	RAY_FAILCAUSE_EIDRANGE	1
#define	RAY_FAILCAUSE_ELENGTH	2
/* device can possibly return up to 255 */
#define	RAY_FAILCAUSE_EDEVSTOP	256

#ifdef _KERNEL
#define	RAY_FAILCAUSE_WAITING	257
#endif

/* get a param the data is a ray_param_request structure */
#define	SIOCSRAYPARAM	SIOCSIFGENERIC
#define	SIOCGRAYPARAM	SIOCGIFGENERIC

#define	RAY_PID_STRINGS	{				\
	"RAY_PID_NET_TYPE",				\
	"RAY_PID_AP_STATUS",				\
	"RAY_PID_SSID",					\
	"RAY_PID_SCAN_MODE",				\
	"RAY_PID_APM_MODE",				\
	"RAY_PID_MAC_ADDR",				\
	"RAY_PID_FRAG_THRESH",				\
	"RAY_PID_DWELL_TIME",				\
	"RAY_PID_BEACON_PERIOD",			\
	"RAY_PID_DTIM_INT",				\
	"RAY_PID_MAX_RETRY",				\
	"RAY_PID_ACK_TIMO",				\
	"RAY_PID_SIFS",					\
	"RAY_PID_DIFS",					\
	"RAY_PID_PIFS",					\
	"RAY_PID_RTS_THRESH",				\
	"RAY_PID_SCAN_DWELL_PERIOD",			\
	"RAY_PID_MAX_SCAN_DWELL_PERIOD",		\
	"RAY_PID_ASSOC_TIMO",				\
	"RAY_PID_ADHOC_SCAN_CYCLE",			\
	"RAY_PID_INFRA_SCAN_CYCLE",			\
	"RAY_PID_INFRA_SUPER_SCAN_CYCLE",		\
	"RAY_PID_PROMISC",				\
	"RAY_PID_UNIQ_WORD",				\
	"RAY_PID_SLOT_TIME",				\
	"RAY_PID_ROAM_LOW_SNR_THRESH",			\
	"RAY_PID_LOW_SNR_COUNT",			\
	"RAY_PID_INFRA_MISSED_BEACON_COUNT",		\
	"RAY_PID_ADHOC_MISSED_BEACON_COUNT",		\
	"RAY_PID_COUNTRY_CODE",				\
	"RAY_PID_HOP_SEQ",				\
	"RAY_PID_HOP_SEQ_LEN",				\
	"RAY_PID_CW_MAX",				\
	"RAY_PID_CW_MIN",				\
	"RAY_PID_NOISE_FILTER_GAIN",			\
	"RAY_PID_NOISE_LIMIT_OFFSET",			\
	"RAY_PID_RSSI_THRESH_OFFSET",			\
	"RAY_PID_BUSY_THRESH_OFFSET",			\
	"RAY_PID_SYNC_THRESH",				\
	"RAY_PID_TEST_MODE",				\
	"RAY_PID_TEST_MIN_CHAN",			\
	"RAY_PID_TEST_MAX_CHAN",			\
	"RAY_PID_ALLOW_PROBE_RESP",			\
	"RAY_PID_PRIVACY_MUST_START",			\
	"RAY_PID_PRIVACY_CAN_JOIN",			\
	"RAY_PID_BASIC_RATE_SET"			\
    }

#ifdef RAY_DO_SIGLEV
#define SIOCGRAYSIGLEV  _IOWR('i', 201, struct ifreq)

#define RAY_NSIGLEVRECS 8
#define RAY_NSIGLEV 8

struct ray_siglev {
	u_int8_t	rsl_host[ETHER_ADDR_LEN]; /* MAC address */
	u_int8_t	rsl_siglevs[RAY_NSIGLEV]; /* levels, newest in [0] */
	struct timeval	rsl_time; 		  /* time of last packet */
};
#endif