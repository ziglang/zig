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
#ifndef __LINUX__WIMAX__I2400M_H__
#define __LINUX__WIMAX__I2400M_H__
#include <linux/types.h>
#include <linux/if_ether.h>
struct i2400m_bcf_hdr {
  __le32 module_type;
  __le32 header_len;
  __le32 header_version;
  __le32 module_id;
  __le32 module_vendor;
  __le32 date;
  __le32 size;
  __le32 key_size;
  __le32 modulus_size;
  __le32 exponent_size;
  __u8 reserved[88];
} __attribute__((packed));
enum i2400m_brh_opcode {
  I2400M_BRH_READ = 1,
  I2400M_BRH_WRITE = 2,
  I2400M_BRH_JUMP = 3,
  I2400M_BRH_SIGNED_JUMP = 8,
  I2400M_BRH_HASH_PAYLOAD_ONLY = 9,
};
enum i2400m_brh {
  I2400M_BRH_SIGNATURE = 0xcbbc0000,
  I2400M_BRH_SIGNATURE_MASK = 0xffff0000,
  I2400M_BRH_SIGNATURE_SHIFT = 16,
  I2400M_BRH_OPCODE_MASK = 0x0000000f,
  I2400M_BRH_RESPONSE_MASK = 0x000000f0,
  I2400M_BRH_RESPONSE_SHIFT = 4,
  I2400M_BRH_DIRECT_ACCESS = 0x00000400,
  I2400M_BRH_RESPONSE_REQUIRED = 0x00000200,
  I2400M_BRH_USE_CHECKSUM = 0x00000100,
};
struct i2400m_bootrom_header {
  __le32 command;
  __le32 target_addr;
  __le32 data_size;
  __le32 block_checksum;
  char payload[0];
} __attribute__((packed));
enum i2400m_pt {
  I2400M_PT_DATA = 0,
  I2400M_PT_CTRL,
  I2400M_PT_TRACE,
  I2400M_PT_RESET_WARM,
  I2400M_PT_RESET_COLD,
  I2400M_PT_EDATA,
  I2400M_PT_ILLEGAL
};
struct i2400m_pl_data_hdr {
  __le32 reserved;
} __attribute__((packed));
struct i2400m_pl_edata_hdr {
  __le32 reorder;
  __u8 cs;
  __u8 reserved[11];
} __attribute__((packed));
enum i2400m_cs {
  I2400M_CS_IPV4_0 = 0,
  I2400M_CS_IPV4 = 2,
};
enum i2400m_ro {
  I2400M_RO_NEEDED = 0x01,
  I2400M_RO_TYPE = 0x03,
  I2400M_RO_TYPE_SHIFT = 1,
  I2400M_RO_CIN = 0x0f,
  I2400M_RO_CIN_SHIFT = 4,
  I2400M_RO_FBN = 0x07ff,
  I2400M_RO_FBN_SHIFT = 8,
  I2400M_RO_SN = 0x07ff,
  I2400M_RO_SN_SHIFT = 21,
};
enum i2400m_ro_type {
  I2400M_RO_TYPE_RESET = 0,
  I2400M_RO_TYPE_PACKET,
  I2400M_RO_TYPE_WS,
  I2400M_RO_TYPE_PACKET_WS,
};
enum {
  I2400M_PL_ALIGN = 16,
  I2400M_PL_SIZE_MAX = 0x3EFF,
  I2400M_MAX_PLS_IN_MSG = 60,
  I2400M_H2D_PREVIEW_BARKER = 0xcafe900d,
  I2400M_COLD_RESET_BARKER = 0xc01dc01d,
  I2400M_WARM_RESET_BARKER = 0x50f750f7,
  I2400M_NBOOT_BARKER = 0xdeadbeef,
  I2400M_SBOOT_BARKER = 0x0ff1c1a1,
  I2400M_SBOOT_BARKER_6050 = 0x80000001,
  I2400M_ACK_BARKER = 0xfeedbabe,
  I2400M_D2H_MSG_BARKER = 0xbeefbabe,
};
struct i2400m_pld {
  __le32 val;
} __attribute__((packed));
#define I2400M_PLD_SIZE_MASK 0x00003fff
#define I2400M_PLD_TYPE_SHIFT 16
#define I2400M_PLD_TYPE_MASK 0x000f0000
struct i2400m_msg_hdr {
  union {
    __le32 barker;
    __u32 size;
  };
  union {
    __le32 sequence;
    __u32 offset;
  };
  __le16 num_pls;
  __le16 rsv1;
  __le16 padding;
  __le16 rsv2;
  struct i2400m_pld pld[0];
} __attribute__((packed));
enum {
  I2400M_L3L4_VERSION = 0x0100,
};
enum i2400m_mt {
  I2400M_MT_RESERVED = 0x0000,
  I2400M_MT_INVALID = 0xffff,
  I2400M_MT_REPORT_MASK = 0x8000,
  I2400M_MT_GET_SCAN_RESULT = 0x4202,
  I2400M_MT_SET_SCAN_PARAM = 0x4402,
  I2400M_MT_CMD_RF_CONTROL = 0x4602,
  I2400M_MT_CMD_SCAN = 0x4603,
  I2400M_MT_CMD_CONNECT = 0x4604,
  I2400M_MT_CMD_DISCONNECT = 0x4605,
  I2400M_MT_CMD_EXIT_IDLE = 0x4606,
  I2400M_MT_GET_LM_VERSION = 0x5201,
  I2400M_MT_GET_DEVICE_INFO = 0x5202,
  I2400M_MT_GET_LINK_STATUS = 0x5203,
  I2400M_MT_GET_STATISTICS = 0x5204,
  I2400M_MT_GET_STATE = 0x5205,
  I2400M_MT_GET_MEDIA_STATUS = 0x5206,
  I2400M_MT_SET_INIT_CONFIG = 0x5404,
  I2400M_MT_CMD_INIT = 0x5601,
  I2400M_MT_CMD_TERMINATE = 0x5602,
  I2400M_MT_CMD_MODE_OF_OP = 0x5603,
  I2400M_MT_CMD_RESET_DEVICE = 0x5604,
  I2400M_MT_CMD_MONITOR_CONTROL = 0x5605,
  I2400M_MT_CMD_ENTER_POWERSAVE = 0x5606,
  I2400M_MT_GET_TLS_OPERATION_RESULT = 0x6201,
  I2400M_MT_SET_EAP_SUCCESS = 0x6402,
  I2400M_MT_SET_EAP_FAIL = 0x6403,
  I2400M_MT_SET_EAP_KEY = 0x6404,
  I2400M_MT_CMD_SEND_EAP_RESPONSE = 0x6602,
  I2400M_MT_REPORT_SCAN_RESULT = 0xc002,
  I2400M_MT_REPORT_STATE = 0xd002,
  I2400M_MT_REPORT_POWERSAVE_READY = 0xd005,
  I2400M_MT_REPORT_EAP_REQUEST = 0xe002,
  I2400M_MT_REPORT_EAP_RESTART = 0xe003,
  I2400M_MT_REPORT_ALT_ACCEPT = 0xe004,
  I2400M_MT_REPORT_KEY_REQUEST = 0xe005,
};
enum i2400m_ms {
  I2400M_MS_DONE_OK = 0,
  I2400M_MS_DONE_IN_PROGRESS = 1,
  I2400M_MS_INVALID_OP = 2,
  I2400M_MS_BAD_STATE = 3,
  I2400M_MS_ILLEGAL_VALUE = 4,
  I2400M_MS_MISSING_PARAMS = 5,
  I2400M_MS_VERSION_ERROR = 6,
  I2400M_MS_ACCESSIBILITY_ERROR = 7,
  I2400M_MS_BUSY = 8,
  I2400M_MS_CORRUPTED_TLV = 9,
  I2400M_MS_UNINITIALIZED = 10,
  I2400M_MS_UNKNOWN_ERROR = 11,
  I2400M_MS_PRODUCTION_ERROR = 12,
  I2400M_MS_NO_RF = 13,
  I2400M_MS_NOT_READY_FOR_POWERSAVE = 14,
  I2400M_MS_THERMAL_CRITICAL = 15,
  I2400M_MS_MAX
};
enum i2400m_tlv {
  I2400M_TLV_L4_MESSAGE_VERSIONS = 129,
  I2400M_TLV_SYSTEM_STATE = 141,
  I2400M_TLV_MEDIA_STATUS = 161,
  I2400M_TLV_RF_OPERATION = 162,
  I2400M_TLV_RF_STATUS = 163,
  I2400M_TLV_DEVICE_RESET_TYPE = 132,
  I2400M_TLV_CONFIG_IDLE_PARAMETERS = 601,
  I2400M_TLV_CONFIG_IDLE_TIMEOUT = 611,
  I2400M_TLV_CONFIG_D2H_DATA_FORMAT = 614,
  I2400M_TLV_CONFIG_DL_HOST_REORDER = 615,
};
struct i2400m_tlv_hdr {
  __le16 type;
  __le16 length;
  __u8 pl[0];
} __attribute__((packed));
struct i2400m_l3l4_hdr {
  __le16 type;
  __le16 length;
  __le16 version;
  __le16 resv1;
  __le16 status;
  __le16 resv2;
  struct i2400m_tlv_hdr pl[0];
} __attribute__((packed));
enum i2400m_system_state {
  I2400M_SS_UNINITIALIZED = 1,
  I2400M_SS_INIT,
  I2400M_SS_READY,
  I2400M_SS_SCAN,
  I2400M_SS_STANDBY,
  I2400M_SS_CONNECTING,
  I2400M_SS_WIMAX_CONNECTED,
  I2400M_SS_DATA_PATH_CONNECTED,
  I2400M_SS_IDLE,
  I2400M_SS_DISCONNECTING,
  I2400M_SS_OUT_OF_ZONE,
  I2400M_SS_SLEEPACTIVE,
  I2400M_SS_PRODUCTION,
  I2400M_SS_CONFIG,
  I2400M_SS_RF_OFF,
  I2400M_SS_RF_SHUTDOWN,
  I2400M_SS_DEVICE_DISCONNECT,
  I2400M_SS_MAX,
};
struct i2400m_tlv_system_state {
  struct i2400m_tlv_hdr hdr;
  __le32 state;
} __attribute__((packed));
struct i2400m_tlv_l4_message_versions {
  struct i2400m_tlv_hdr hdr;
  __le16 major;
  __le16 minor;
  __le16 branch;
  __le16 reserved;
} __attribute__((packed));
struct i2400m_tlv_detailed_device_info {
  struct i2400m_tlv_hdr hdr;
  __u8 reserved1[400];
  __u8 mac_address[ETH_ALEN];
  __u8 reserved2[2];
} __attribute__((packed));
enum i2400m_rf_switch_status {
  I2400M_RF_SWITCH_ON = 1,
  I2400M_RF_SWITCH_OFF = 2,
};
struct i2400m_tlv_rf_switches_status {
  struct i2400m_tlv_hdr hdr;
  __u8 sw_rf_switch;
  __u8 hw_rf_switch;
  __u8 reserved[2];
} __attribute__((packed));
enum {
  i2400m_rf_operation_on = 1,
  i2400m_rf_operation_off = 2
};
struct i2400m_tlv_rf_operation {
  struct i2400m_tlv_hdr hdr;
  __le32 status;
} __attribute__((packed));
enum i2400m_tlv_reset_type {
  I2400M_RESET_TYPE_COLD = 1,
  I2400M_RESET_TYPE_WARM
};
struct i2400m_tlv_device_reset_type {
  struct i2400m_tlv_hdr hdr;
  __le32 reset_type;
} __attribute__((packed));
struct i2400m_tlv_config_idle_parameters {
  struct i2400m_tlv_hdr hdr;
  __le32 idle_timeout;
  __le32 idle_paging_interval;
} __attribute__((packed));
enum i2400m_media_status {
  I2400M_MEDIA_STATUS_LINK_UP = 1,
  I2400M_MEDIA_STATUS_LINK_DOWN,
  I2400M_MEDIA_STATUS_LINK_RENEW,
};
struct i2400m_tlv_media_status {
  struct i2400m_tlv_hdr hdr;
  __le32 media_status;
} __attribute__((packed));
struct i2400m_tlv_config_idle_timeout {
  struct i2400m_tlv_hdr hdr;
  __le32 timeout;
} __attribute__((packed));
struct i2400m_tlv_config_d2h_data_format {
  struct i2400m_tlv_hdr hdr;
  __u8 format;
  __u8 reserved[3];
} __attribute__((packed));
struct i2400m_tlv_config_dl_host_reorder {
  struct i2400m_tlv_hdr hdr;
  __u8 reorder;
  __u8 reserved[3];
} __attribute__((packed));
#endif