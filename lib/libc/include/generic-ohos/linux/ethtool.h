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
#ifndef _UAPI_LINUX_ETHTOOL_H
#define _UAPI_LINUX_ETHTOOL_H
#include <linux/kernel.h>
#include <linux/types.h>
#include <linux/if_ether.h>
#include <limits.h>
struct ethtool_cmd {
  __u32 cmd;
  __u32 supported;
  __u32 advertising;
  __u16 speed;
  __u8 duplex;
  __u8 port;
  __u8 phy_address;
  __u8 transceiver;
  __u8 autoneg;
  __u8 mdio_support;
  __u32 maxtxpkt;
  __u32 maxrxpkt;
  __u16 speed_hi;
  __u8 eth_tp_mdix;
  __u8 eth_tp_mdix_ctrl;
  __u32 lp_advertising;
  __u32 reserved[2];
};
#define ETH_MDIO_SUPPORTS_C22 1
#define ETH_MDIO_SUPPORTS_C45 2
#define ETHTOOL_FWVERS_LEN 32
#define ETHTOOL_BUSINFO_LEN 32
#define ETHTOOL_EROMVERS_LEN 32
struct ethtool_drvinfo {
  __u32 cmd;
  char driver[32];
  char version[32];
  char fw_version[ETHTOOL_FWVERS_LEN];
  char bus_info[ETHTOOL_BUSINFO_LEN];
  char erom_version[ETHTOOL_EROMVERS_LEN];
  char reserved2[12];
  __u32 n_priv_flags;
  __u32 n_stats;
  __u32 testinfo_len;
  __u32 eedump_len;
  __u32 regdump_len;
};
#define SOPASS_MAX 6
struct ethtool_wolinfo {
  __u32 cmd;
  __u32 supported;
  __u32 wolopts;
  __u8 sopass[SOPASS_MAX];
};
struct ethtool_value {
  __u32 cmd;
  __u32 data;
};
#define PFC_STORM_PREVENTION_AUTO 0xffff
#define PFC_STORM_PREVENTION_DISABLE 0
enum tunable_id {
  ETHTOOL_ID_UNSPEC,
  ETHTOOL_RX_COPYBREAK,
  ETHTOOL_TX_COPYBREAK,
  ETHTOOL_PFC_PREVENTION_TOUT,
  __ETHTOOL_TUNABLE_COUNT,
};
enum tunable_type_id {
  ETHTOOL_TUNABLE_UNSPEC,
  ETHTOOL_TUNABLE_U8,
  ETHTOOL_TUNABLE_U16,
  ETHTOOL_TUNABLE_U32,
  ETHTOOL_TUNABLE_U64,
  ETHTOOL_TUNABLE_STRING,
  ETHTOOL_TUNABLE_S8,
  ETHTOOL_TUNABLE_S16,
  ETHTOOL_TUNABLE_S32,
  ETHTOOL_TUNABLE_S64,
};
struct ethtool_tunable {
  __u32 cmd;
  __u32 id;
  __u32 type_id;
  __u32 len;
  void * data[0];
};
#define DOWNSHIFT_DEV_DEFAULT_COUNT 0xff
#define DOWNSHIFT_DEV_DISABLE 0
#define ETHTOOL_PHY_FAST_LINK_DOWN_ON 0
#define ETHTOOL_PHY_FAST_LINK_DOWN_OFF 0xff
#define ETHTOOL_PHY_EDPD_DFLT_TX_MSECS 0xffff
#define ETHTOOL_PHY_EDPD_NO_TX 0xfffe
#define ETHTOOL_PHY_EDPD_DISABLE 0
enum phy_tunable_id {
  ETHTOOL_PHY_ID_UNSPEC,
  ETHTOOL_PHY_DOWNSHIFT,
  ETHTOOL_PHY_FAST_LINK_DOWN,
  ETHTOOL_PHY_EDPD,
  __ETHTOOL_PHY_TUNABLE_COUNT,
};
struct ethtool_regs {
  __u32 cmd;
  __u32 version;
  __u32 len;
  __u8 data[0];
};
struct ethtool_eeprom {
  __u32 cmd;
  __u32 magic;
  __u32 offset;
  __u32 len;
  __u8 data[0];
};
struct ethtool_eee {
  __u32 cmd;
  __u32 supported;
  __u32 advertised;
  __u32 lp_advertised;
  __u32 eee_active;
  __u32 eee_enabled;
  __u32 tx_lpi_enabled;
  __u32 tx_lpi_timer;
  __u32 reserved[2];
};
struct ethtool_modinfo {
  __u32 cmd;
  __u32 type;
  __u32 eeprom_len;
  __u32 reserved[8];
};
struct ethtool_coalesce {
  __u32 cmd;
  __u32 rx_coalesce_usecs;
  __u32 rx_max_coalesced_frames;
  __u32 rx_coalesce_usecs_irq;
  __u32 rx_max_coalesced_frames_irq;
  __u32 tx_coalesce_usecs;
  __u32 tx_max_coalesced_frames;
  __u32 tx_coalesce_usecs_irq;
  __u32 tx_max_coalesced_frames_irq;
  __u32 stats_block_coalesce_usecs;
  __u32 use_adaptive_rx_coalesce;
  __u32 use_adaptive_tx_coalesce;
  __u32 pkt_rate_low;
  __u32 rx_coalesce_usecs_low;
  __u32 rx_max_coalesced_frames_low;
  __u32 tx_coalesce_usecs_low;
  __u32 tx_max_coalesced_frames_low;
  __u32 pkt_rate_high;
  __u32 rx_coalesce_usecs_high;
  __u32 rx_max_coalesced_frames_high;
  __u32 tx_coalesce_usecs_high;
  __u32 tx_max_coalesced_frames_high;
  __u32 rate_sample_interval;
};
struct ethtool_ringparam {
  __u32 cmd;
  __u32 rx_max_pending;
  __u32 rx_mini_max_pending;
  __u32 rx_jumbo_max_pending;
  __u32 tx_max_pending;
  __u32 rx_pending;
  __u32 rx_mini_pending;
  __u32 rx_jumbo_pending;
  __u32 tx_pending;
};
struct ethtool_channels {
  __u32 cmd;
  __u32 max_rx;
  __u32 max_tx;
  __u32 max_other;
  __u32 max_combined;
  __u32 rx_count;
  __u32 tx_count;
  __u32 other_count;
  __u32 combined_count;
};
struct ethtool_pauseparam {
  __u32 cmd;
  __u32 autoneg;
  __u32 rx_pause;
  __u32 tx_pause;
};
enum ethtool_link_ext_state {
  ETHTOOL_LINK_EXT_STATE_AUTONEG,
  ETHTOOL_LINK_EXT_STATE_LINK_TRAINING_FAILURE,
  ETHTOOL_LINK_EXT_STATE_LINK_LOGICAL_MISMATCH,
  ETHTOOL_LINK_EXT_STATE_BAD_SIGNAL_INTEGRITY,
  ETHTOOL_LINK_EXT_STATE_NO_CABLE,
  ETHTOOL_LINK_EXT_STATE_CABLE_ISSUE,
  ETHTOOL_LINK_EXT_STATE_EEPROM_ISSUE,
  ETHTOOL_LINK_EXT_STATE_CALIBRATION_FAILURE,
  ETHTOOL_LINK_EXT_STATE_POWER_BUDGET_EXCEEDED,
  ETHTOOL_LINK_EXT_STATE_OVERHEAT,
};
enum ethtool_link_ext_substate_autoneg {
  ETHTOOL_LINK_EXT_SUBSTATE_AN_NO_PARTNER_DETECTED = 1,
  ETHTOOL_LINK_EXT_SUBSTATE_AN_ACK_NOT_RECEIVED,
  ETHTOOL_LINK_EXT_SUBSTATE_AN_NEXT_PAGE_EXCHANGE_FAILED,
  ETHTOOL_LINK_EXT_SUBSTATE_AN_NO_PARTNER_DETECTED_FORCE_MODE,
  ETHTOOL_LINK_EXT_SUBSTATE_AN_FEC_MISMATCH_DURING_OVERRIDE,
  ETHTOOL_LINK_EXT_SUBSTATE_AN_NO_HCD,
};
enum ethtool_link_ext_substate_link_training {
  ETHTOOL_LINK_EXT_SUBSTATE_LT_KR_FRAME_LOCK_NOT_ACQUIRED = 1,
  ETHTOOL_LINK_EXT_SUBSTATE_LT_KR_LINK_INHIBIT_TIMEOUT,
  ETHTOOL_LINK_EXT_SUBSTATE_LT_KR_LINK_PARTNER_DID_NOT_SET_RECEIVER_READY,
  ETHTOOL_LINK_EXT_SUBSTATE_LT_REMOTE_FAULT,
};
enum ethtool_link_ext_substate_link_logical_mismatch {
  ETHTOOL_LINK_EXT_SUBSTATE_LLM_PCS_DID_NOT_ACQUIRE_BLOCK_LOCK = 1,
  ETHTOOL_LINK_EXT_SUBSTATE_LLM_PCS_DID_NOT_ACQUIRE_AM_LOCK,
  ETHTOOL_LINK_EXT_SUBSTATE_LLM_PCS_DID_NOT_GET_ALIGN_STATUS,
  ETHTOOL_LINK_EXT_SUBSTATE_LLM_FC_FEC_IS_NOT_LOCKED,
  ETHTOOL_LINK_EXT_SUBSTATE_LLM_RS_FEC_IS_NOT_LOCKED,
};
enum ethtool_link_ext_substate_bad_signal_integrity {
  ETHTOOL_LINK_EXT_SUBSTATE_BSI_LARGE_NUMBER_OF_PHYSICAL_ERRORS = 1,
  ETHTOOL_LINK_EXT_SUBSTATE_BSI_UNSUPPORTED_RATE,
};
enum ethtool_link_ext_substate_cable_issue {
  ETHTOOL_LINK_EXT_SUBSTATE_CI_UNSUPPORTED_CABLE = 1,
  ETHTOOL_LINK_EXT_SUBSTATE_CI_CABLE_TEST_FAILURE,
};
#define ETH_GSTRING_LEN 32
enum ethtool_stringset {
  ETH_SS_TEST = 0,
  ETH_SS_STATS,
  ETH_SS_PRIV_FLAGS,
  ETH_SS_NTUPLE_FILTERS,
  ETH_SS_FEATURES,
  ETH_SS_RSS_HASH_FUNCS,
  ETH_SS_TUNABLES,
  ETH_SS_PHY_STATS,
  ETH_SS_PHY_TUNABLES,
  ETH_SS_LINK_MODES,
  ETH_SS_MSG_CLASSES,
  ETH_SS_WOL_MODES,
  ETH_SS_SOF_TIMESTAMPING,
  ETH_SS_TS_TX_TYPES,
  ETH_SS_TS_RX_FILTERS,
  ETH_SS_UDP_TUNNEL_TYPES,
  ETH_SS_COUNT
};
struct ethtool_gstrings {
  __u32 cmd;
  __u32 string_set;
  __u32 len;
  __u8 data[0];
};
struct ethtool_sset_info {
  __u32 cmd;
  __u32 reserved;
  __u64 sset_mask;
  __u32 data[0];
};
enum ethtool_test_flags {
  ETH_TEST_FL_OFFLINE = (1 << 0),
  ETH_TEST_FL_FAILED = (1 << 1),
  ETH_TEST_FL_EXTERNAL_LB = (1 << 2),
  ETH_TEST_FL_EXTERNAL_LB_DONE = (1 << 3),
};
struct ethtool_test {
  __u32 cmd;
  __u32 flags;
  __u32 reserved;
  __u32 len;
  __u64 data[0];
};
struct ethtool_stats {
  __u32 cmd;
  __u32 n_stats;
  __u64 data[0];
};
struct ethtool_perm_addr {
  __u32 cmd;
  __u32 size;
  __u8 data[0];
};
enum ethtool_flags {
  ETH_FLAG_TXVLAN = (1 << 7),
  ETH_FLAG_RXVLAN = (1 << 8),
  ETH_FLAG_LRO = (1 << 15),
  ETH_FLAG_NTUPLE = (1 << 27),
  ETH_FLAG_RXHASH = (1 << 28),
};
struct ethtool_tcpip4_spec {
  __be32 ip4src;
  __be32 ip4dst;
  __be16 psrc;
  __be16 pdst;
  __u8 tos;
};
struct ethtool_ah_espip4_spec {
  __be32 ip4src;
  __be32 ip4dst;
  __be32 spi;
  __u8 tos;
};
#define ETH_RX_NFC_IP4 1
struct ethtool_usrip4_spec {
  __be32 ip4src;
  __be32 ip4dst;
  __be32 l4_4_bytes;
  __u8 tos;
  __u8 ip_ver;
  __u8 proto;
};
struct ethtool_tcpip6_spec {
  __be32 ip6src[4];
  __be32 ip6dst[4];
  __be16 psrc;
  __be16 pdst;
  __u8 tclass;
};
struct ethtool_ah_espip6_spec {
  __be32 ip6src[4];
  __be32 ip6dst[4];
  __be32 spi;
  __u8 tclass;
};
struct ethtool_usrip6_spec {
  __be32 ip6src[4];
  __be32 ip6dst[4];
  __be32 l4_4_bytes;
  __u8 tclass;
  __u8 l4_proto;
};
union ethtool_flow_union {
  struct ethtool_tcpip4_spec tcp_ip4_spec;
  struct ethtool_tcpip4_spec udp_ip4_spec;
  struct ethtool_tcpip4_spec sctp_ip4_spec;
  struct ethtool_ah_espip4_spec ah_ip4_spec;
  struct ethtool_ah_espip4_spec esp_ip4_spec;
  struct ethtool_usrip4_spec usr_ip4_spec;
  struct ethtool_tcpip6_spec tcp_ip6_spec;
  struct ethtool_tcpip6_spec udp_ip6_spec;
  struct ethtool_tcpip6_spec sctp_ip6_spec;
  struct ethtool_ah_espip6_spec ah_ip6_spec;
  struct ethtool_ah_espip6_spec esp_ip6_spec;
  struct ethtool_usrip6_spec usr_ip6_spec;
  struct ethhdr ether_spec;
  __u8 hdata[52];
};
struct ethtool_flow_ext {
  __u8 padding[2];
  unsigned char h_dest[ETH_ALEN];
  __be16 vlan_etype;
  __be16 vlan_tci;
  __be32 data[2];
};
struct ethtool_rx_flow_spec {
  __u32 flow_type;
  union ethtool_flow_union h_u;
  struct ethtool_flow_ext h_ext;
  union ethtool_flow_union m_u;
  struct ethtool_flow_ext m_ext;
  __u64 ring_cookie;
  __u32 location;
};
#define ETHTOOL_RX_FLOW_SPEC_RING 0x00000000FFFFFFFFLL
#define ETHTOOL_RX_FLOW_SPEC_RING_VF 0x000000FF00000000LL
#define ETHTOOL_RX_FLOW_SPEC_RING_VF_OFF 32
struct ethtool_rxnfc {
  __u32 cmd;
  __u32 flow_type;
  __u64 data;
  struct ethtool_rx_flow_spec fs;
  union {
    __u32 rule_cnt;
    __u32 rss_context;
  };
  __u32 rule_locs[0];
};
struct ethtool_rxfh_indir {
  __u32 cmd;
  __u32 size;
  __u32 ring_index[0];
};
struct ethtool_rxfh {
  __u32 cmd;
  __u32 rss_context;
  __u32 indir_size;
  __u32 key_size;
  __u8 hfunc;
  __u8 rsvd8[3];
  __u32 rsvd32;
  __u32 rss_config[0];
};
#define ETH_RXFH_CONTEXT_ALLOC 0xffffffff
#define ETH_RXFH_INDIR_NO_CHANGE 0xffffffff
struct ethtool_rx_ntuple_flow_spec {
  __u32 flow_type;
  union {
    struct ethtool_tcpip4_spec tcp_ip4_spec;
    struct ethtool_tcpip4_spec udp_ip4_spec;
    struct ethtool_tcpip4_spec sctp_ip4_spec;
    struct ethtool_ah_espip4_spec ah_ip4_spec;
    struct ethtool_ah_espip4_spec esp_ip4_spec;
    struct ethtool_usrip4_spec usr_ip4_spec;
    struct ethhdr ether_spec;
    __u8 hdata[72];
  } h_u, m_u;
  __u16 vlan_tag;
  __u16 vlan_tag_mask;
  __u64 data;
  __u64 data_mask;
  __s32 action;
#define ETHTOOL_RXNTUPLE_ACTION_DROP (- 1)
#define ETHTOOL_RXNTUPLE_ACTION_CLEAR (- 2)
};
struct ethtool_rx_ntuple {
  __u32 cmd;
  struct ethtool_rx_ntuple_flow_spec fs;
};
#define ETHTOOL_FLASH_MAX_FILENAME 128
enum ethtool_flash_op_type {
  ETHTOOL_FLASH_ALL_REGIONS = 0,
};
struct ethtool_flash {
  __u32 cmd;
  __u32 region;
  char data[ETHTOOL_FLASH_MAX_FILENAME];
};
struct ethtool_dump {
  __u32 cmd;
  __u32 version;
  __u32 flag;
  __u32 len;
  __u8 data[0];
};
#define ETH_FW_DUMP_DISABLE 0
struct ethtool_get_features_block {
  __u32 available;
  __u32 requested;
  __u32 active;
  __u32 never_changed;
};
struct ethtool_gfeatures {
  __u32 cmd;
  __u32 size;
  struct ethtool_get_features_block features[0];
};
struct ethtool_set_features_block {
  __u32 valid;
  __u32 requested;
};
struct ethtool_sfeatures {
  __u32 cmd;
  __u32 size;
  struct ethtool_set_features_block features[0];
};
struct ethtool_ts_info {
  __u32 cmd;
  __u32 so_timestamping;
  __s32 phc_index;
  __u32 tx_types;
  __u32 tx_reserved[3];
  __u32 rx_filters;
  __u32 rx_reserved[3];
};
enum ethtool_sfeatures_retval_bits {
  ETHTOOL_F_UNSUPPORTED__BIT,
  ETHTOOL_F_WISH__BIT,
  ETHTOOL_F_COMPAT__BIT,
};
#define ETHTOOL_F_UNSUPPORTED (1 << ETHTOOL_F_UNSUPPORTED__BIT)
#define ETHTOOL_F_WISH (1 << ETHTOOL_F_WISH__BIT)
#define ETHTOOL_F_COMPAT (1 << ETHTOOL_F_COMPAT__BIT)
#define MAX_NUM_QUEUE 4096
struct ethtool_per_queue_op {
  __u32 cmd;
  __u32 sub_command;
  __u32 queue_mask[__KERNEL_DIV_ROUND_UP(MAX_NUM_QUEUE, 32)];
  char data[];
};
struct ethtool_fecparam {
  __u32 cmd;
  __u32 active_fec;
  __u32 fec;
  __u32 reserved;
};
enum ethtool_fec_config_bits {
  ETHTOOL_FEC_NONE_BIT,
  ETHTOOL_FEC_AUTO_BIT,
  ETHTOOL_FEC_OFF_BIT,
  ETHTOOL_FEC_RS_BIT,
  ETHTOOL_FEC_BASER_BIT,
  ETHTOOL_FEC_LLRS_BIT,
};
#define ETHTOOL_FEC_NONE (1 << ETHTOOL_FEC_NONE_BIT)
#define ETHTOOL_FEC_AUTO (1 << ETHTOOL_FEC_AUTO_BIT)
#define ETHTOOL_FEC_OFF (1 << ETHTOOL_FEC_OFF_BIT)
#define ETHTOOL_FEC_RS (1 << ETHTOOL_FEC_RS_BIT)
#define ETHTOOL_FEC_BASER (1 << ETHTOOL_FEC_BASER_BIT)
#define ETHTOOL_FEC_LLRS (1 << ETHTOOL_FEC_LLRS_BIT)
#define ETHTOOL_GSET 0x00000001
#define ETHTOOL_SSET 0x00000002
#define ETHTOOL_GDRVINFO 0x00000003
#define ETHTOOL_GREGS 0x00000004
#define ETHTOOL_GWOL 0x00000005
#define ETHTOOL_SWOL 0x00000006
#define ETHTOOL_GMSGLVL 0x00000007
#define ETHTOOL_SMSGLVL 0x00000008
#define ETHTOOL_NWAY_RST 0x00000009
#define ETHTOOL_GLINK 0x0000000a
#define ETHTOOL_GEEPROM 0x0000000b
#define ETHTOOL_SEEPROM 0x0000000c
#define ETHTOOL_GCOALESCE 0x0000000e
#define ETHTOOL_SCOALESCE 0x0000000f
#define ETHTOOL_GRINGPARAM 0x00000010
#define ETHTOOL_SRINGPARAM 0x00000011
#define ETHTOOL_GPAUSEPARAM 0x00000012
#define ETHTOOL_SPAUSEPARAM 0x00000013
#define ETHTOOL_GRXCSUM 0x00000014
#define ETHTOOL_SRXCSUM 0x00000015
#define ETHTOOL_GTXCSUM 0x00000016
#define ETHTOOL_STXCSUM 0x00000017
#define ETHTOOL_GSG 0x00000018
#define ETHTOOL_SSG 0x00000019
#define ETHTOOL_TEST 0x0000001a
#define ETHTOOL_GSTRINGS 0x0000001b
#define ETHTOOL_PHYS_ID 0x0000001c
#define ETHTOOL_GSTATS 0x0000001d
#define ETHTOOL_GTSO 0x0000001e
#define ETHTOOL_STSO 0x0000001f
#define ETHTOOL_GPERMADDR 0x00000020
#define ETHTOOL_GUFO 0x00000021
#define ETHTOOL_SUFO 0x00000022
#define ETHTOOL_GGSO 0x00000023
#define ETHTOOL_SGSO 0x00000024
#define ETHTOOL_GFLAGS 0x00000025
#define ETHTOOL_SFLAGS 0x00000026
#define ETHTOOL_GPFLAGS 0x00000027
#define ETHTOOL_SPFLAGS 0x00000028
#define ETHTOOL_GRXFH 0x00000029
#define ETHTOOL_SRXFH 0x0000002a
#define ETHTOOL_GGRO 0x0000002b
#define ETHTOOL_SGRO 0x0000002c
#define ETHTOOL_GRXRINGS 0x0000002d
#define ETHTOOL_GRXCLSRLCNT 0x0000002e
#define ETHTOOL_GRXCLSRULE 0x0000002f
#define ETHTOOL_GRXCLSRLALL 0x00000030
#define ETHTOOL_SRXCLSRLDEL 0x00000031
#define ETHTOOL_SRXCLSRLINS 0x00000032
#define ETHTOOL_FLASHDEV 0x00000033
#define ETHTOOL_RESET 0x00000034
#define ETHTOOL_SRXNTUPLE 0x00000035
#define ETHTOOL_GRXNTUPLE 0x00000036
#define ETHTOOL_GSSET_INFO 0x00000037
#define ETHTOOL_GRXFHINDIR 0x00000038
#define ETHTOOL_SRXFHINDIR 0x00000039
#define ETHTOOL_GFEATURES 0x0000003a
#define ETHTOOL_SFEATURES 0x0000003b
#define ETHTOOL_GCHANNELS 0x0000003c
#define ETHTOOL_SCHANNELS 0x0000003d
#define ETHTOOL_SET_DUMP 0x0000003e
#define ETHTOOL_GET_DUMP_FLAG 0x0000003f
#define ETHTOOL_GET_DUMP_DATA 0x00000040
#define ETHTOOL_GET_TS_INFO 0x00000041
#define ETHTOOL_GMODULEINFO 0x00000042
#define ETHTOOL_GMODULEEEPROM 0x00000043
#define ETHTOOL_GEEE 0x00000044
#define ETHTOOL_SEEE 0x00000045
#define ETHTOOL_GRSSH 0x00000046
#define ETHTOOL_SRSSH 0x00000047
#define ETHTOOL_GTUNABLE 0x00000048
#define ETHTOOL_STUNABLE 0x00000049
#define ETHTOOL_GPHYSTATS 0x0000004a
#define ETHTOOL_PERQUEUE 0x0000004b
#define ETHTOOL_GLINKSETTINGS 0x0000004c
#define ETHTOOL_SLINKSETTINGS 0x0000004d
#define ETHTOOL_PHY_GTUNABLE 0x0000004e
#define ETHTOOL_PHY_STUNABLE 0x0000004f
#define ETHTOOL_GFECPARAM 0x00000050
#define ETHTOOL_SFECPARAM 0x00000051
#define SPARC_ETH_GSET ETHTOOL_GSET
#define SPARC_ETH_SSET ETHTOOL_SSET
enum ethtool_link_mode_bit_indices {
  ETHTOOL_LINK_MODE_10baseT_Half_BIT = 0,
  ETHTOOL_LINK_MODE_10baseT_Full_BIT = 1,
  ETHTOOL_LINK_MODE_100baseT_Half_BIT = 2,
  ETHTOOL_LINK_MODE_100baseT_Full_BIT = 3,
  ETHTOOL_LINK_MODE_1000baseT_Half_BIT = 4,
  ETHTOOL_LINK_MODE_1000baseT_Full_BIT = 5,
  ETHTOOL_LINK_MODE_Autoneg_BIT = 6,
  ETHTOOL_LINK_MODE_TP_BIT = 7,
  ETHTOOL_LINK_MODE_AUI_BIT = 8,
  ETHTOOL_LINK_MODE_MII_BIT = 9,
  ETHTOOL_LINK_MODE_FIBRE_BIT = 10,
  ETHTOOL_LINK_MODE_BNC_BIT = 11,
  ETHTOOL_LINK_MODE_10000baseT_Full_BIT = 12,
  ETHTOOL_LINK_MODE_Pause_BIT = 13,
  ETHTOOL_LINK_MODE_Asym_Pause_BIT = 14,
  ETHTOOL_LINK_MODE_2500baseX_Full_BIT = 15,
  ETHTOOL_LINK_MODE_Backplane_BIT = 16,
  ETHTOOL_LINK_MODE_1000baseKX_Full_BIT = 17,
  ETHTOOL_LINK_MODE_10000baseKX4_Full_BIT = 18,
  ETHTOOL_LINK_MODE_10000baseKR_Full_BIT = 19,
  ETHTOOL_LINK_MODE_10000baseR_FEC_BIT = 20,
  ETHTOOL_LINK_MODE_20000baseMLD2_Full_BIT = 21,
  ETHTOOL_LINK_MODE_20000baseKR2_Full_BIT = 22,
  ETHTOOL_LINK_MODE_40000baseKR4_Full_BIT = 23,
  ETHTOOL_LINK_MODE_40000baseCR4_Full_BIT = 24,
  ETHTOOL_LINK_MODE_40000baseSR4_Full_BIT = 25,
  ETHTOOL_LINK_MODE_40000baseLR4_Full_BIT = 26,
  ETHTOOL_LINK_MODE_56000baseKR4_Full_BIT = 27,
  ETHTOOL_LINK_MODE_56000baseCR4_Full_BIT = 28,
  ETHTOOL_LINK_MODE_56000baseSR4_Full_BIT = 29,
  ETHTOOL_LINK_MODE_56000baseLR4_Full_BIT = 30,
  ETHTOOL_LINK_MODE_25000baseCR_Full_BIT = 31,
  ETHTOOL_LINK_MODE_25000baseKR_Full_BIT = 32,
  ETHTOOL_LINK_MODE_25000baseSR_Full_BIT = 33,
  ETHTOOL_LINK_MODE_50000baseCR2_Full_BIT = 34,
  ETHTOOL_LINK_MODE_50000baseKR2_Full_BIT = 35,
  ETHTOOL_LINK_MODE_100000baseKR4_Full_BIT = 36,
  ETHTOOL_LINK_MODE_100000baseSR4_Full_BIT = 37,
  ETHTOOL_LINK_MODE_100000baseCR4_Full_BIT = 38,
  ETHTOOL_LINK_MODE_100000baseLR4_ER4_Full_BIT = 39,
  ETHTOOL_LINK_MODE_50000baseSR2_Full_BIT = 40,
  ETHTOOL_LINK_MODE_1000baseX_Full_BIT = 41,
  ETHTOOL_LINK_MODE_10000baseCR_Full_BIT = 42,
  ETHTOOL_LINK_MODE_10000baseSR_Full_BIT = 43,
  ETHTOOL_LINK_MODE_10000baseLR_Full_BIT = 44,
  ETHTOOL_LINK_MODE_10000baseLRM_Full_BIT = 45,
  ETHTOOL_LINK_MODE_10000baseER_Full_BIT = 46,
  ETHTOOL_LINK_MODE_2500baseT_Full_BIT = 47,
  ETHTOOL_LINK_MODE_5000baseT_Full_BIT = 48,
  ETHTOOL_LINK_MODE_FEC_NONE_BIT = 49,
  ETHTOOL_LINK_MODE_FEC_RS_BIT = 50,
  ETHTOOL_LINK_MODE_FEC_BASER_BIT = 51,
  ETHTOOL_LINK_MODE_50000baseKR_Full_BIT = 52,
  ETHTOOL_LINK_MODE_50000baseSR_Full_BIT = 53,
  ETHTOOL_LINK_MODE_50000baseCR_Full_BIT = 54,
  ETHTOOL_LINK_MODE_50000baseLR_ER_FR_Full_BIT = 55,
  ETHTOOL_LINK_MODE_50000baseDR_Full_BIT = 56,
  ETHTOOL_LINK_MODE_100000baseKR2_Full_BIT = 57,
  ETHTOOL_LINK_MODE_100000baseSR2_Full_BIT = 58,
  ETHTOOL_LINK_MODE_100000baseCR2_Full_BIT = 59,
  ETHTOOL_LINK_MODE_100000baseLR2_ER2_FR2_Full_BIT = 60,
  ETHTOOL_LINK_MODE_100000baseDR2_Full_BIT = 61,
  ETHTOOL_LINK_MODE_200000baseKR4_Full_BIT = 62,
  ETHTOOL_LINK_MODE_200000baseSR4_Full_BIT = 63,
  ETHTOOL_LINK_MODE_200000baseLR4_ER4_FR4_Full_BIT = 64,
  ETHTOOL_LINK_MODE_200000baseDR4_Full_BIT = 65,
  ETHTOOL_LINK_MODE_200000baseCR4_Full_BIT = 66,
  ETHTOOL_LINK_MODE_100baseT1_Full_BIT = 67,
  ETHTOOL_LINK_MODE_1000baseT1_Full_BIT = 68,
  ETHTOOL_LINK_MODE_400000baseKR8_Full_BIT = 69,
  ETHTOOL_LINK_MODE_400000baseSR8_Full_BIT = 70,
  ETHTOOL_LINK_MODE_400000baseLR8_ER8_FR8_Full_BIT = 71,
  ETHTOOL_LINK_MODE_400000baseDR8_Full_BIT = 72,
  ETHTOOL_LINK_MODE_400000baseCR8_Full_BIT = 73,
  ETHTOOL_LINK_MODE_FEC_LLRS_BIT = 74,
  ETHTOOL_LINK_MODE_100000baseKR_Full_BIT = 75,
  ETHTOOL_LINK_MODE_100000baseSR_Full_BIT = 76,
  ETHTOOL_LINK_MODE_100000baseLR_ER_FR_Full_BIT = 77,
  ETHTOOL_LINK_MODE_100000baseCR_Full_BIT = 78,
  ETHTOOL_LINK_MODE_100000baseDR_Full_BIT = 79,
  ETHTOOL_LINK_MODE_200000baseKR2_Full_BIT = 80,
  ETHTOOL_LINK_MODE_200000baseSR2_Full_BIT = 81,
  ETHTOOL_LINK_MODE_200000baseLR2_ER2_FR2_Full_BIT = 82,
  ETHTOOL_LINK_MODE_200000baseDR2_Full_BIT = 83,
  ETHTOOL_LINK_MODE_200000baseCR2_Full_BIT = 84,
  ETHTOOL_LINK_MODE_400000baseKR4_Full_BIT = 85,
  ETHTOOL_LINK_MODE_400000baseSR4_Full_BIT = 86,
  ETHTOOL_LINK_MODE_400000baseLR4_ER4_FR4_Full_BIT = 87,
  ETHTOOL_LINK_MODE_400000baseDR4_Full_BIT = 88,
  ETHTOOL_LINK_MODE_400000baseCR4_Full_BIT = 89,
  ETHTOOL_LINK_MODE_100baseFX_Half_BIT = 90,
  ETHTOOL_LINK_MODE_100baseFX_Full_BIT = 91,
  __ETHTOOL_LINK_MODE_MASK_NBITS
};
#define __ETHTOOL_LINK_MODE_LEGACY_MASK(base_name) (1UL << (ETHTOOL_LINK_MODE_ ##base_name ##_BIT))
#define SUPPORTED_10baseT_Half __ETHTOOL_LINK_MODE_LEGACY_MASK(10baseT_Half)
#define SUPPORTED_10baseT_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(10baseT_Full)
#define SUPPORTED_100baseT_Half __ETHTOOL_LINK_MODE_LEGACY_MASK(100baseT_Half)
#define SUPPORTED_100baseT_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(100baseT_Full)
#define SUPPORTED_1000baseT_Half __ETHTOOL_LINK_MODE_LEGACY_MASK(1000baseT_Half)
#define SUPPORTED_1000baseT_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(1000baseT_Full)
#define SUPPORTED_Autoneg __ETHTOOL_LINK_MODE_LEGACY_MASK(Autoneg)
#define SUPPORTED_TP __ETHTOOL_LINK_MODE_LEGACY_MASK(TP)
#define SUPPORTED_AUI __ETHTOOL_LINK_MODE_LEGACY_MASK(AUI)
#define SUPPORTED_MII __ETHTOOL_LINK_MODE_LEGACY_MASK(MII)
#define SUPPORTED_FIBRE __ETHTOOL_LINK_MODE_LEGACY_MASK(FIBRE)
#define SUPPORTED_BNC __ETHTOOL_LINK_MODE_LEGACY_MASK(BNC)
#define SUPPORTED_10000baseT_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(10000baseT_Full)
#define SUPPORTED_Pause __ETHTOOL_LINK_MODE_LEGACY_MASK(Pause)
#define SUPPORTED_Asym_Pause __ETHTOOL_LINK_MODE_LEGACY_MASK(Asym_Pause)
#define SUPPORTED_2500baseX_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(2500baseX_Full)
#define SUPPORTED_Backplane __ETHTOOL_LINK_MODE_LEGACY_MASK(Backplane)
#define SUPPORTED_1000baseKX_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(1000baseKX_Full)
#define SUPPORTED_10000baseKX4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(10000baseKX4_Full)
#define SUPPORTED_10000baseKR_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(10000baseKR_Full)
#define SUPPORTED_10000baseR_FEC __ETHTOOL_LINK_MODE_LEGACY_MASK(10000baseR_FEC)
#define SUPPORTED_20000baseMLD2_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(20000baseMLD2_Full)
#define SUPPORTED_20000baseKR2_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(20000baseKR2_Full)
#define SUPPORTED_40000baseKR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(40000baseKR4_Full)
#define SUPPORTED_40000baseCR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(40000baseCR4_Full)
#define SUPPORTED_40000baseSR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(40000baseSR4_Full)
#define SUPPORTED_40000baseLR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(40000baseLR4_Full)
#define SUPPORTED_56000baseKR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(56000baseKR4_Full)
#define SUPPORTED_56000baseCR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(56000baseCR4_Full)
#define SUPPORTED_56000baseSR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(56000baseSR4_Full)
#define SUPPORTED_56000baseLR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(56000baseLR4_Full)
#define ADVERTISED_10baseT_Half __ETHTOOL_LINK_MODE_LEGACY_MASK(10baseT_Half)
#define ADVERTISED_10baseT_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(10baseT_Full)
#define ADVERTISED_100baseT_Half __ETHTOOL_LINK_MODE_LEGACY_MASK(100baseT_Half)
#define ADVERTISED_100baseT_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(100baseT_Full)
#define ADVERTISED_1000baseT_Half __ETHTOOL_LINK_MODE_LEGACY_MASK(1000baseT_Half)
#define ADVERTISED_1000baseT_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(1000baseT_Full)
#define ADVERTISED_Autoneg __ETHTOOL_LINK_MODE_LEGACY_MASK(Autoneg)
#define ADVERTISED_TP __ETHTOOL_LINK_MODE_LEGACY_MASK(TP)
#define ADVERTISED_AUI __ETHTOOL_LINK_MODE_LEGACY_MASK(AUI)
#define ADVERTISED_MII __ETHTOOL_LINK_MODE_LEGACY_MASK(MII)
#define ADVERTISED_FIBRE __ETHTOOL_LINK_MODE_LEGACY_MASK(FIBRE)
#define ADVERTISED_BNC __ETHTOOL_LINK_MODE_LEGACY_MASK(BNC)
#define ADVERTISED_10000baseT_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(10000baseT_Full)
#define ADVERTISED_Pause __ETHTOOL_LINK_MODE_LEGACY_MASK(Pause)
#define ADVERTISED_Asym_Pause __ETHTOOL_LINK_MODE_LEGACY_MASK(Asym_Pause)
#define ADVERTISED_2500baseX_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(2500baseX_Full)
#define ADVERTISED_Backplane __ETHTOOL_LINK_MODE_LEGACY_MASK(Backplane)
#define ADVERTISED_1000baseKX_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(1000baseKX_Full)
#define ADVERTISED_10000baseKX4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(10000baseKX4_Full)
#define ADVERTISED_10000baseKR_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(10000baseKR_Full)
#define ADVERTISED_10000baseR_FEC __ETHTOOL_LINK_MODE_LEGACY_MASK(10000baseR_FEC)
#define ADVERTISED_20000baseMLD2_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(20000baseMLD2_Full)
#define ADVERTISED_20000baseKR2_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(20000baseKR2_Full)
#define ADVERTISED_40000baseKR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(40000baseKR4_Full)
#define ADVERTISED_40000baseCR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(40000baseCR4_Full)
#define ADVERTISED_40000baseSR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(40000baseSR4_Full)
#define ADVERTISED_40000baseLR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(40000baseLR4_Full)
#define ADVERTISED_56000baseKR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(56000baseKR4_Full)
#define ADVERTISED_56000baseCR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(56000baseCR4_Full)
#define ADVERTISED_56000baseSR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(56000baseSR4_Full)
#define ADVERTISED_56000baseLR4_Full __ETHTOOL_LINK_MODE_LEGACY_MASK(56000baseLR4_Full)
#define SPEED_10 10
#define SPEED_100 100
#define SPEED_1000 1000
#define SPEED_2500 2500
#define SPEED_5000 5000
#define SPEED_10000 10000
#define SPEED_14000 14000
#define SPEED_20000 20000
#define SPEED_25000 25000
#define SPEED_40000 40000
#define SPEED_50000 50000
#define SPEED_56000 56000
#define SPEED_100000 100000
#define SPEED_200000 200000
#define SPEED_400000 400000
#define SPEED_UNKNOWN - 1
#define DUPLEX_HALF 0x00
#define DUPLEX_FULL 0x01
#define DUPLEX_UNKNOWN 0xff
#define MASTER_SLAVE_CFG_UNSUPPORTED 0
#define MASTER_SLAVE_CFG_UNKNOWN 1
#define MASTER_SLAVE_CFG_MASTER_PREFERRED 2
#define MASTER_SLAVE_CFG_SLAVE_PREFERRED 3
#define MASTER_SLAVE_CFG_MASTER_FORCE 4
#define MASTER_SLAVE_CFG_SLAVE_FORCE 5
#define MASTER_SLAVE_STATE_UNSUPPORTED 0
#define MASTER_SLAVE_STATE_UNKNOWN 1
#define MASTER_SLAVE_STATE_MASTER 2
#define MASTER_SLAVE_STATE_SLAVE 3
#define MASTER_SLAVE_STATE_ERR 4
#define PORT_TP 0x00
#define PORT_AUI 0x01
#define PORT_MII 0x02
#define PORT_FIBRE 0x03
#define PORT_BNC 0x04
#define PORT_DA 0x05
#define PORT_NONE 0xef
#define PORT_OTHER 0xff
#define XCVR_INTERNAL 0x00
#define XCVR_EXTERNAL 0x01
#define XCVR_DUMMY1 0x02
#define XCVR_DUMMY2 0x03
#define XCVR_DUMMY3 0x04
#define AUTONEG_DISABLE 0x00
#define AUTONEG_ENABLE 0x01
#define ETH_TP_MDI_INVALID 0x00
#define ETH_TP_MDI 0x01
#define ETH_TP_MDI_X 0x02
#define ETH_TP_MDI_AUTO 0x03
#define WAKE_PHY (1 << 0)
#define WAKE_UCAST (1 << 1)
#define WAKE_MCAST (1 << 2)
#define WAKE_BCAST (1 << 3)
#define WAKE_ARP (1 << 4)
#define WAKE_MAGIC (1 << 5)
#define WAKE_MAGICSECURE (1 << 6)
#define WAKE_FILTER (1 << 7)
#define WOL_MODE_COUNT 8
#define TCP_V4_FLOW 0x01
#define UDP_V4_FLOW 0x02
#define SCTP_V4_FLOW 0x03
#define AH_ESP_V4_FLOW 0x04
#define TCP_V6_FLOW 0x05
#define UDP_V6_FLOW 0x06
#define SCTP_V6_FLOW 0x07
#define AH_ESP_V6_FLOW 0x08
#define AH_V4_FLOW 0x09
#define ESP_V4_FLOW 0x0a
#define AH_V6_FLOW 0x0b
#define ESP_V6_FLOW 0x0c
#define IPV4_USER_FLOW 0x0d
#define IP_USER_FLOW IPV4_USER_FLOW
#define IPV6_USER_FLOW 0x0e
#define IPV4_FLOW 0x10
#define IPV6_FLOW 0x11
#define ETHER_FLOW 0x12
#define FLOW_EXT 0x80000000
#define FLOW_MAC_EXT 0x40000000
#define FLOW_RSS 0x20000000
#define RXH_L2DA (1 << 1)
#define RXH_VLAN (1 << 2)
#define RXH_L3_PROTO (1 << 3)
#define RXH_IP_SRC (1 << 4)
#define RXH_IP_DST (1 << 5)
#define RXH_L4_B_0_1 (1 << 6)
#define RXH_L4_B_2_3 (1 << 7)
#define RXH_DISCARD (1 << 31)
#define RX_CLS_FLOW_DISC 0xffffffffffffffffULL
#define RX_CLS_FLOW_WAKE 0xfffffffffffffffeULL
#define RX_CLS_LOC_SPECIAL 0x80000000
#define RX_CLS_LOC_ANY 0xffffffff
#define RX_CLS_LOC_FIRST 0xfffffffe
#define RX_CLS_LOC_LAST 0xfffffffd
#define ETH_MODULE_SFF_8079 0x1
#define ETH_MODULE_SFF_8079_LEN 256
#define ETH_MODULE_SFF_8472 0x2
#define ETH_MODULE_SFF_8472_LEN 512
#define ETH_MODULE_SFF_8636 0x3
#define ETH_MODULE_SFF_8636_LEN 256
#define ETH_MODULE_SFF_8436 0x4
#define ETH_MODULE_SFF_8436_LEN 256
#define ETH_MODULE_SFF_8636_MAX_LEN 640
#define ETH_MODULE_SFF_8436_MAX_LEN 640
enum ethtool_reset_flags {
  ETH_RESET_MGMT = 1 << 0,
  ETH_RESET_IRQ = 1 << 1,
  ETH_RESET_DMA = 1 << 2,
  ETH_RESET_FILTER = 1 << 3,
  ETH_RESET_OFFLOAD = 1 << 4,
  ETH_RESET_MAC = 1 << 5,
  ETH_RESET_PHY = 1 << 6,
  ETH_RESET_RAM = 1 << 7,
  ETH_RESET_AP = 1 << 8,
  ETH_RESET_DEDICATED = 0x0000ffff,
  ETH_RESET_ALL = 0xffffffff,
};
#define ETH_RESET_SHARED_SHIFT 16
struct ethtool_link_settings {
  __u32 cmd;
  __u32 speed;
  __u8 duplex;
  __u8 port;
  __u8 phy_address;
  __u8 autoneg;
  __u8 mdio_support;
  __u8 eth_tp_mdix;
  __u8 eth_tp_mdix_ctrl;
  __s8 link_mode_masks_nwords;
  __u8 transceiver;
  __u8 master_slave_cfg;
  __u8 master_slave_state;
  __u8 reserved1[1];
  __u32 reserved[7];
  __u32 link_mode_masks[0];
};
#endif