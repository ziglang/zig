/* $NetBSD: dtvio_frontend.h,v 1.3 2017/10/28 06:27:32 riastradh Exp $ */

/*-
 * Copyright (c) 2011 Jared D. McNeill <jmcneill@invisible.ca>
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *        This product includes software developed by Jared D. McNeill.
 * 4. Neither the name of The NetBSD Foundation nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
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

#ifndef _DEV_DTV_DTVIO_FRONTEND_H
#define _DEV_DTV_DTVIO_FRONTEND_H

#include <sys/types.h>
#include <sys/ioccom.h>

/*
 * DVB Frontend API
 */

/* Frontend types */
typedef enum fe_type {
	FE_QPSK,	/* DVB-S */
	FE_QAM,		/* DVB-C annex A/C */
	FE_OFDM,	/* DVB-T */
	FE_ATSC,	/* ATSC or DVB-C annex B */
} fe_type_t;

/* Frontend capabilities */
typedef enum fe_caps {
	FE_IS_STUPID			= 0,
	FE_CAN_INVERSION_AUTO		= 0x1,
	FE_CAN_FEC_1_2			= 0x2,
	FE_CAN_FEC_2_3			= 0x4,
	FE_CAN_FEC_3_4			= 0x8,
	FE_CAN_FEC_4_5			= 0x10,
	FE_CAN_FEC_5_6			= 0x20,
	FE_CAN_FEC_6_7			= 0x40,
	FE_CAN_FEC_7_8			= 0x80,
	FE_CAN_FEC_8_9			= 0x100,
	FE_CAN_FEC_AUTO			= 0x200,
	FE_CAN_QPSK			= 0x400,
	FE_CAN_QAM_16			= 0x800,
	FE_CAN_QAM_32			= 0x1000,
	FE_CAN_QAM_64			= 0x2000,
	FE_CAN_QAM_128			= 0x4000,
	FE_CAN_QAM_256			= 0x8000,
	FE_CAN_QAM_AUTO			= 0x10000,
	FE_CAN_TRANSMISSION_MODE_AUTO	= 0x20000,
	FE_CAN_BANDWIDTH_AUTO		= 0x40000,
	FE_CAN_GUARD_INTERVAL_AUTO	= 0x80000,
	FE_CAN_HIERARCHY_AUTO		= 0x100000,
	FE_CAN_8VSB			= 0x200000,
	FE_CAN_16VSB			= 0x400000,
	FE_HAS_EXTENDED_CAPS		= 0x800000,
	FE_CAN_TURBO_FEC		= 0x8000000,
	FE_CAN_2G_MODULATION		= 0x10000000,
	FE_NEEDS_BENDING		= 0x20000000,
	FE_CAN_RECOVER			= 0x40000000,
	FE_CAN_MUTE_TS			= 0x80000000,
} fe_caps_t;

/* Frontend information */
struct dvb_frontend_info {
	char		name[128];
	fe_type_t	type;
	uint32_t	frequency_min;
	uint32_t	frequency_max;
	uint32_t	frequency_stepsize;
	uint32_t	frequency_tolerance;
	uint32_t	symbol_rate_min;
	uint32_t	symbol_rate_max;
	uint32_t	symbol_rate_tolerance;	/* ppm */
	uint32_t	notifier_delay;		/* ms */
	fe_caps_t	caps;
};

/* Frontend status */
typedef enum fe_status {
	FE_HAS_SIGNAL	= 0x01,	/* found something above the noise level */
	FE_HAS_CARRIER	= 0x02,	/* found a DVB signal */
	FE_HAS_VITERBI	= 0x04,	/* FEC is stable */
	FE_HAS_SYNC	= 0x08,	/* found sync bytes */
	FE_HAS_LOCK	= 0x10,	/* everything's working... */
	FE_TIMEDOUT	= 0x20,	/* no lock within the last ~2 seconds */
	FE_REINIT	= 0x40,	/* frontend was reinitialized */
} fe_status_t;

/* Frontend spectral inversion */
typedef enum fe_spectral_inversion {
	INVERSION_OFF,
	INVERSION_ON,
	INVERSION_AUTO,
} fe_spectral_inversion_t;

/* Frontend code rate */
typedef enum fe_code_rate {
	FEC_NONE = 0,
	FEC_1_2,
	FEC_2_3,
	FEC_3_4,
	FEC_4_5,
	FEC_5_6,
	FEC_6_7,
	FEC_7_8,
	FEC_8_9,
	FEC_AUTO,
	FEC_3_5,
	FEC_9_10,
} fe_code_rate_t;

/* Frontend modulation type for QAM, OFDM, and VSB */
typedef enum fe_modulation {
	QPSK,
	QAM_16,
	QAM_32,
	QAM_64,
	QAM_128,
	QAM_256,
	QAM_AUTO,
	VSB_8,
	VSB_16,
	PSK_8,
	APSK_16,
	APSK_32,
	DQPSK,
} fe_modulation_t;

/* Number of carriers per channel */
typedef enum fe_transmit_mode {
	TRANSMISSION_MODE_2K,
	TRANSMISSION_MODE_8K,
	TRANSMISSION_MODE_AUTO,
	TRANSMISSION_MODE_4K,
	TRANSMISSION_MODE_1K,
	TRANSMISSION_MODE_16K,
	TRANSMISSION_MODE_32K,
} fe_transmit_mode_t;

/* Frontend bandwidth */
typedef enum fe_bandwidth {
	BANDWIDTH_8_MHZ,
	BANDWIDTH_7_MHZ,
	BANDWIDTH_6_MHZ,
	BANDWIDTH_AUTO,
	BANDWIDTH_5_MHZ,
	BANDWIDTH_10_MHZ,
	BANDWIDTH_1_172_MHZ,
} fe_bandwidth_t;

/* Frontend guard interval */
typedef enum fe_guard_interval {
	GUARD_INTERVAL_1_32,
	GUARD_INTERVAL_1_16,
	GUARD_INTERVAL_1_8,
	GUARD_INTERVAL_1_4,
	GUARD_INTERVAL_AUTO,
	GUARD_INTERVAL_1_128,
	GUARD_INTERVAL_19_128,
	GUARD_INTERVAL_19_256,
} fe_guard_interval_t;

/* Frontend hierarchy */
typedef enum fe_hierarchy {
	HIERARCHY_NONE,
	HIERARCHY_1,
	HIERARCHY_2,
	HIERARCHY_4,
	HIERARCHY_AUTO
} fe_hierarchy_t;

/* QPSK parameters */
struct dvb_qpsk_parameters {
	uint32_t	symbol_rate;
	fe_code_rate_t	fec_inner;
};

/* QAM parameters */
struct dvb_qam_parameters {
	uint32_t	symbol_rate;
	fe_code_rate_t	fec_inner;
	fe_modulation_t	modulation;
};

/* VSB parameters */
struct dvb_vsb_parameters {
	fe_modulation_t	modulation;
};

/* OFDM parameters */
struct dvb_ofdm_parameters {
	fe_bandwidth_t		bandwidth;
	fe_code_rate_t		code_rate_HP;
	fe_code_rate_t		code_rate_LP;
	fe_modulation_t		constellation;
	fe_transmit_mode_t	transmission_mode;
	fe_guard_interval_t	guard_interval;
	fe_hierarchy_t		hierarchy_information;
};

/* Frontend parameters */
struct dvb_frontend_parameters {
	uint32_t		frequency;
	fe_spectral_inversion_t	inversion;
	union {
		struct dvb_qpsk_parameters	qpsk;
		struct dvb_qam_parameters	qam;
		struct dvb_ofdm_parameters	ofdm;
		struct dvb_vsb_parameters	vsb;
	} u;
};

/* Frontend events */
struct dvb_frontend_event {
	fe_status_t			status;
	struct dvb_frontend_parameters	parameters;
};

/* DiSEqC master command */
struct dvb_diseqc_master_cmd {
	uint8_t		msg[6];
	uint8_t		msg_len;
};

/* DiSEqC slave reply */
struct dvb_diseqc_slave_reply {
	uint8_t		msg[4];
	uint8_t		msg_len;
	int		timeout;
};

/* SEC voltage */
typedef enum fe_sec_voltage {
	SEC_VOLTAGE_13,
	SEC_VOLTAGE_18,
	SEC_VOLTAGE_OFF,
} fe_sec_voltage_t;

/* SEC continuous tone */
typedef enum fe_sec_tone_mode {
	SEC_TONE_ON,
	SEC_TONE_OFF,
} fe_sec_tone_mode_t;

/* SEC tone burst */
typedef enum fe_sec_mini_cmd {
	SEC_MINI_A,
	SEC_MINI_B,
} fe_sec_mini_cmd_t;

#define	FE_READ_STATUS		   _IOR('D', 0, fe_status_t)
#define	FE_READ_BER		   _IOR('D', 1, uint32_t)
#define	FE_READ_SNR		   _IOR('D', 2, uint16_t)
#define	FE_READ_SIGNAL_STRENGTH	   _IOR('D', 3, uint16_t)
#define	FE_READ_UNCORRECTED_BLOCKS _IOR('D', 4, uint32_t)
#define	FE_SET_FRONTEND		   _IOWR('D', 5, struct dvb_frontend_parameters)
#define	FE_GET_FRONTEND		   _IOR('D', 6, struct dvb_frontend_parameters)
#define	FE_GET_EVENT		   _IOR('D', 7, struct dvb_frontend_event)
#define	FE_GET_INFO		   _IOR('D', 8, struct dvb_frontend_info)
#define	FE_DISEQC_RESET_OVERLOAD   _IO('D', 9)
#define	FE_DISEQC_SEND_MASTER_CMD  _IOW('D', 10, struct dvb_diseqc_master_cmd)
#define	FE_DISEQC_RECV_SLAVE_REPLY _IOR('D', 11, struct dvb_diseqc_slave_reply)
#define	FE_DISEQC_SEND_BURST	   _IOW('D', 12, fe_sec_mini_cmd_t)
#define	FE_SET_TONE		   _IOW('D', 13, fe_sec_tone_mode_t)
#define	FE_SET_VOLTAGE		   _IOW('D', 14, fe_sec_voltage_t)
#define	FE_ENABLE_HIGH_LNB_VOLTAGE _IOW('D', 15, int)
#define	FE_SET_FRONTEND_TUNE_MODE  _IOW('D', 16, unsigned int)
#define	FE_DISHNETWORK_SEND_LEGACY_CMD _IOW('D', 17, unsigned long)

#endif /* !_DEV_DTV_DTVIO_FRONTEND_H */