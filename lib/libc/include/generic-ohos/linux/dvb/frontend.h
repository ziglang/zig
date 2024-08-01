/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _DVBFRONTEND_H_
#define _DVBFRONTEND_H_
#include <linux/types.h>
enum fe_caps {
  FE_IS_STUPID = 0,
  FE_CAN_INVERSION_AUTO = 0x1,
  FE_CAN_FEC_1_2 = 0x2,
  FE_CAN_FEC_2_3 = 0x4,
  FE_CAN_FEC_3_4 = 0x8,
  FE_CAN_FEC_4_5 = 0x10,
  FE_CAN_FEC_5_6 = 0x20,
  FE_CAN_FEC_6_7 = 0x40,
  FE_CAN_FEC_7_8 = 0x80,
  FE_CAN_FEC_8_9 = 0x100,
  FE_CAN_FEC_AUTO = 0x200,
  FE_CAN_QPSK = 0x400,
  FE_CAN_QAM_16 = 0x800,
  FE_CAN_QAM_32 = 0x1000,
  FE_CAN_QAM_64 = 0x2000,
  FE_CAN_QAM_128 = 0x4000,
  FE_CAN_QAM_256 = 0x8000,
  FE_CAN_QAM_AUTO = 0x10000,
  FE_CAN_TRANSMISSION_MODE_AUTO = 0x20000,
  FE_CAN_BANDWIDTH_AUTO = 0x40000,
  FE_CAN_GUARD_INTERVAL_AUTO = 0x80000,
  FE_CAN_HIERARCHY_AUTO = 0x100000,
  FE_CAN_8VSB = 0x200000,
  FE_CAN_16VSB = 0x400000,
  FE_HAS_EXTENDED_CAPS = 0x800000,
  FE_CAN_MULTISTREAM = 0x4000000,
  FE_CAN_TURBO_FEC = 0x8000000,
  FE_CAN_2G_MODULATION = 0x10000000,
  FE_NEEDS_BENDING = 0x20000000,
  FE_CAN_RECOVER = 0x40000000,
  FE_CAN_MUTE_TS = 0x80000000
};
enum fe_type {
  FE_QPSK,
  FE_QAM,
  FE_OFDM,
  FE_ATSC
};
struct dvb_frontend_info {
  char name[128];
  enum fe_type type;
  __u32 frequency_min;
  __u32 frequency_max;
  __u32 frequency_stepsize;
  __u32 frequency_tolerance;
  __u32 symbol_rate_min;
  __u32 symbol_rate_max;
  __u32 symbol_rate_tolerance;
  __u32 notifier_delay;
  enum fe_caps caps;
};
struct dvb_diseqc_master_cmd {
  __u8 msg[6];
  __u8 msg_len;
};
struct dvb_diseqc_slave_reply {
  __u8 msg[4];
  __u8 msg_len;
  int timeout;
};
enum fe_sec_voltage {
  SEC_VOLTAGE_13,
  SEC_VOLTAGE_18,
  SEC_VOLTAGE_OFF
};
enum fe_sec_tone_mode {
  SEC_TONE_ON,
  SEC_TONE_OFF
};
enum fe_sec_mini_cmd {
  SEC_MINI_A,
  SEC_MINI_B
};
enum fe_status {
  FE_NONE = 0x00,
  FE_HAS_SIGNAL = 0x01,
  FE_HAS_CARRIER = 0x02,
  FE_HAS_VITERBI = 0x04,
  FE_HAS_SYNC = 0x08,
  FE_HAS_LOCK = 0x10,
  FE_TIMEDOUT = 0x20,
  FE_REINIT = 0x40,
};
enum fe_spectral_inversion {
  INVERSION_OFF,
  INVERSION_ON,
  INVERSION_AUTO
};
enum fe_code_rate {
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
  FEC_2_5,
};
enum fe_modulation {
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
  QAM_4_NR,
};
enum fe_transmit_mode {
  TRANSMISSION_MODE_2K,
  TRANSMISSION_MODE_8K,
  TRANSMISSION_MODE_AUTO,
  TRANSMISSION_MODE_4K,
  TRANSMISSION_MODE_1K,
  TRANSMISSION_MODE_16K,
  TRANSMISSION_MODE_32K,
  TRANSMISSION_MODE_C1,
  TRANSMISSION_MODE_C3780,
};
enum fe_guard_interval {
  GUARD_INTERVAL_1_32,
  GUARD_INTERVAL_1_16,
  GUARD_INTERVAL_1_8,
  GUARD_INTERVAL_1_4,
  GUARD_INTERVAL_AUTO,
  GUARD_INTERVAL_1_128,
  GUARD_INTERVAL_19_128,
  GUARD_INTERVAL_19_256,
  GUARD_INTERVAL_PN420,
  GUARD_INTERVAL_PN595,
  GUARD_INTERVAL_PN945,
};
enum fe_hierarchy {
  HIERARCHY_NONE,
  HIERARCHY_1,
  HIERARCHY_2,
  HIERARCHY_4,
  HIERARCHY_AUTO
};
enum fe_interleaving {
  INTERLEAVING_NONE,
  INTERLEAVING_AUTO,
  INTERLEAVING_240,
  INTERLEAVING_720,
};
#define DTV_UNDEFINED 0
#define DTV_TUNE 1
#define DTV_CLEAR 2
#define DTV_FREQUENCY 3
#define DTV_MODULATION 4
#define DTV_BANDWIDTH_HZ 5
#define DTV_INVERSION 6
#define DTV_DISEQC_MASTER 7
#define DTV_SYMBOL_RATE 8
#define DTV_INNER_FEC 9
#define DTV_VOLTAGE 10
#define DTV_TONE 11
#define DTV_PILOT 12
#define DTV_ROLLOFF 13
#define DTV_DISEQC_SLAVE_REPLY 14
#define DTV_FE_CAPABILITY_COUNT 15
#define DTV_FE_CAPABILITY 16
#define DTV_DELIVERY_SYSTEM 17
#define DTV_ISDBT_PARTIAL_RECEPTION 18
#define DTV_ISDBT_SOUND_BROADCASTING 19
#define DTV_ISDBT_SB_SUBCHANNEL_ID 20
#define DTV_ISDBT_SB_SEGMENT_IDX 21
#define DTV_ISDBT_SB_SEGMENT_COUNT 22
#define DTV_ISDBT_LAYERA_FEC 23
#define DTV_ISDBT_LAYERA_MODULATION 24
#define DTV_ISDBT_LAYERA_SEGMENT_COUNT 25
#define DTV_ISDBT_LAYERA_TIME_INTERLEAVING 26
#define DTV_ISDBT_LAYERB_FEC 27
#define DTV_ISDBT_LAYERB_MODULATION 28
#define DTV_ISDBT_LAYERB_SEGMENT_COUNT 29
#define DTV_ISDBT_LAYERB_TIME_INTERLEAVING 30
#define DTV_ISDBT_LAYERC_FEC 31
#define DTV_ISDBT_LAYERC_MODULATION 32
#define DTV_ISDBT_LAYERC_SEGMENT_COUNT 33
#define DTV_ISDBT_LAYERC_TIME_INTERLEAVING 34
#define DTV_API_VERSION 35
#define DTV_CODE_RATE_HP 36
#define DTV_CODE_RATE_LP 37
#define DTV_GUARD_INTERVAL 38
#define DTV_TRANSMISSION_MODE 39
#define DTV_HIERARCHY 40
#define DTV_ISDBT_LAYER_ENABLED 41
#define DTV_STREAM_ID 42
#define DTV_ISDBS_TS_ID_LEGACY DTV_STREAM_ID
#define DTV_DVBT2_PLP_ID_LEGACY 43
#define DTV_ENUM_DELSYS 44
#define DTV_ATSCMH_FIC_VER 45
#define DTV_ATSCMH_PARADE_ID 46
#define DTV_ATSCMH_NOG 47
#define DTV_ATSCMH_TNOG 48
#define DTV_ATSCMH_SGN 49
#define DTV_ATSCMH_PRC 50
#define DTV_ATSCMH_RS_FRAME_MODE 51
#define DTV_ATSCMH_RS_FRAME_ENSEMBLE 52
#define DTV_ATSCMH_RS_CODE_MODE_PRI 53
#define DTV_ATSCMH_RS_CODE_MODE_SEC 54
#define DTV_ATSCMH_SCCC_BLOCK_MODE 55
#define DTV_ATSCMH_SCCC_CODE_MODE_A 56
#define DTV_ATSCMH_SCCC_CODE_MODE_B 57
#define DTV_ATSCMH_SCCC_CODE_MODE_C 58
#define DTV_ATSCMH_SCCC_CODE_MODE_D 59
#define DTV_INTERLEAVING 60
#define DTV_LNA 61
#define DTV_STAT_SIGNAL_STRENGTH 62
#define DTV_STAT_CNR 63
#define DTV_STAT_PRE_ERROR_BIT_COUNT 64
#define DTV_STAT_PRE_TOTAL_BIT_COUNT 65
#define DTV_STAT_POST_ERROR_BIT_COUNT 66
#define DTV_STAT_POST_TOTAL_BIT_COUNT 67
#define DTV_STAT_ERROR_BLOCK_COUNT 68
#define DTV_STAT_TOTAL_BLOCK_COUNT 69
#define DTV_SCRAMBLING_SEQUENCE_INDEX 70
#define DTV_MAX_COMMAND DTV_SCRAMBLING_SEQUENCE_INDEX
enum fe_pilot {
  PILOT_ON,
  PILOT_OFF,
  PILOT_AUTO,
};
enum fe_rolloff {
  ROLLOFF_35,
  ROLLOFF_20,
  ROLLOFF_25,
  ROLLOFF_AUTO,
};
enum fe_delivery_system {
  SYS_UNDEFINED,
  SYS_DVBC_ANNEX_A,
  SYS_DVBC_ANNEX_B,
  SYS_DVBT,
  SYS_DSS,
  SYS_DVBS,
  SYS_DVBS2,
  SYS_DVBH,
  SYS_ISDBT,
  SYS_ISDBS,
  SYS_ISDBC,
  SYS_ATSC,
  SYS_ATSCMH,
  SYS_DTMB,
  SYS_CMMB,
  SYS_DAB,
  SYS_DVBT2,
  SYS_TURBO,
  SYS_DVBC_ANNEX_C,
};
#define SYS_DVBC_ANNEX_AC SYS_DVBC_ANNEX_A
#define SYS_DMBTH SYS_DTMB
enum atscmh_sccc_block_mode {
  ATSCMH_SCCC_BLK_SEP = 0,
  ATSCMH_SCCC_BLK_COMB = 1,
  ATSCMH_SCCC_BLK_RES = 2,
};
enum atscmh_sccc_code_mode {
  ATSCMH_SCCC_CODE_HLF = 0,
  ATSCMH_SCCC_CODE_QTR = 1,
  ATSCMH_SCCC_CODE_RES = 2,
};
enum atscmh_rs_frame_ensemble {
  ATSCMH_RSFRAME_ENS_PRI = 0,
  ATSCMH_RSFRAME_ENS_SEC = 1,
};
enum atscmh_rs_frame_mode {
  ATSCMH_RSFRAME_PRI_ONLY = 0,
  ATSCMH_RSFRAME_PRI_SEC = 1,
  ATSCMH_RSFRAME_RES = 2,
};
enum atscmh_rs_code_mode {
  ATSCMH_RSCODE_211_187 = 0,
  ATSCMH_RSCODE_223_187 = 1,
  ATSCMH_RSCODE_235_187 = 2,
  ATSCMH_RSCODE_RES = 3,
};
#define NO_STREAM_ID_FILTER (~0U)
#define LNA_AUTO (~0U)
enum fecap_scale_params {
  FE_SCALE_NOT_AVAILABLE = 0,
  FE_SCALE_DECIBEL,
  FE_SCALE_RELATIVE,
  FE_SCALE_COUNTER
};
struct dtv_stats {
  __u8 scale;
  union {
    __u64 uvalue;
    __s64 svalue;
  };
} __attribute__((packed));
#define MAX_DTV_STATS 4
struct dtv_fe_stats {
  __u8 len;
  struct dtv_stats stat[MAX_DTV_STATS];
} __attribute__((packed));
struct dtv_property {
  __u32 cmd;
  __u32 reserved[3];
  union {
    __u32 data;
    struct dtv_fe_stats st;
    struct {
      __u8 data[32];
      __u32 len;
      __u32 reserved1[3];
      void * reserved2;
    } buffer;
  } u;
  int result;
} __attribute__((packed));
#define DTV_IOCTL_MAX_MSGS 64
struct dtv_properties {
  __u32 num;
  struct dtv_property * props;
};
#define FE_TUNE_MODE_ONESHOT 0x01
#define FE_GET_INFO _IOR('o', 61, struct dvb_frontend_info)
#define FE_DISEQC_RESET_OVERLOAD _IO('o', 62)
#define FE_DISEQC_SEND_MASTER_CMD _IOW('o', 63, struct dvb_diseqc_master_cmd)
#define FE_DISEQC_RECV_SLAVE_REPLY _IOR('o', 64, struct dvb_diseqc_slave_reply)
#define FE_DISEQC_SEND_BURST _IO('o', 65)
#define FE_SET_TONE _IO('o', 66)
#define FE_SET_VOLTAGE _IO('o', 67)
#define FE_ENABLE_HIGH_LNB_VOLTAGE _IO('o', 68)
#define FE_READ_STATUS _IOR('o', 69, fe_status_t)
#define FE_READ_BER _IOR('o', 70, __u32)
#define FE_READ_SIGNAL_STRENGTH _IOR('o', 71, __u16)
#define FE_READ_SNR _IOR('o', 72, __u16)
#define FE_READ_UNCORRECTED_BLOCKS _IOR('o', 73, __u32)
#define FE_SET_FRONTEND_TUNE_MODE _IO('o', 81)
#define FE_GET_EVENT _IOR('o', 78, struct dvb_frontend_event)
#define FE_DISHNETWORK_SEND_LEGACY_CMD _IO('o', 80)
#define FE_SET_PROPERTY _IOW('o', 82, struct dtv_properties)
#define FE_GET_PROPERTY _IOR('o', 83, struct dtv_properties)
enum fe_bandwidth {
  BANDWIDTH_8_MHZ,
  BANDWIDTH_7_MHZ,
  BANDWIDTH_6_MHZ,
  BANDWIDTH_AUTO,
  BANDWIDTH_5_MHZ,
  BANDWIDTH_10_MHZ,
  BANDWIDTH_1_712_MHZ,
};
typedef enum fe_sec_voltage fe_sec_voltage_t;
typedef enum fe_caps fe_caps_t;
typedef enum fe_type fe_type_t;
typedef enum fe_sec_tone_mode fe_sec_tone_mode_t;
typedef enum fe_sec_mini_cmd fe_sec_mini_cmd_t;
typedef enum fe_status fe_status_t;
typedef enum fe_spectral_inversion fe_spectral_inversion_t;
typedef enum fe_code_rate fe_code_rate_t;
typedef enum fe_modulation fe_modulation_t;
typedef enum fe_transmit_mode fe_transmit_mode_t;
typedef enum fe_bandwidth fe_bandwidth_t;
typedef enum fe_guard_interval fe_guard_interval_t;
typedef enum fe_hierarchy fe_hierarchy_t;
typedef enum fe_pilot fe_pilot_t;
typedef enum fe_rolloff fe_rolloff_t;
typedef enum fe_delivery_system fe_delivery_system_t;
struct dvb_qpsk_parameters {
  __u32 symbol_rate;
  fe_code_rate_t fec_inner;
};
struct dvb_qam_parameters {
  __u32 symbol_rate;
  fe_code_rate_t fec_inner;
  fe_modulation_t modulation;
};
struct dvb_vsb_parameters {
  fe_modulation_t modulation;
};
struct dvb_ofdm_parameters {
  fe_bandwidth_t bandwidth;
  fe_code_rate_t code_rate_HP;
  fe_code_rate_t code_rate_LP;
  fe_modulation_t constellation;
  fe_transmit_mode_t transmission_mode;
  fe_guard_interval_t guard_interval;
  fe_hierarchy_t hierarchy_information;
};
struct dvb_frontend_parameters {
  __u32 frequency;
  fe_spectral_inversion_t inversion;
  union {
    struct dvb_qpsk_parameters qpsk;
    struct dvb_qam_parameters qam;
    struct dvb_ofdm_parameters ofdm;
    struct dvb_vsb_parameters vsb;
  } u;
};
struct dvb_frontend_event {
  fe_status_t status;
  struct dvb_frontend_parameters parameters;
};
#define FE_SET_FRONTEND _IOW('o', 76, struct dvb_frontend_parameters)
#define FE_GET_FRONTEND _IOR('o', 77, struct dvb_frontend_parameters)
#endif