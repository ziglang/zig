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
#ifndef _UAPI_LINUX_VIRTIO_NET_H
#define _UAPI_LINUX_VIRTIO_NET_H
#include <linux/types.h>
#include <linux/virtio_ids.h>
#include <linux/virtio_config.h>
#include <linux/virtio_types.h>
#include <linux/if_ether.h>
#define VIRTIO_NET_F_CSUM 0
#define VIRTIO_NET_F_GUEST_CSUM 1
#define VIRTIO_NET_F_CTRL_GUEST_OFFLOADS 2
#define VIRTIO_NET_F_MTU 3
#define VIRTIO_NET_F_MAC 5
#define VIRTIO_NET_F_GUEST_TSO4 7
#define VIRTIO_NET_F_GUEST_TSO6 8
#define VIRTIO_NET_F_GUEST_ECN 9
#define VIRTIO_NET_F_GUEST_UFO 10
#define VIRTIO_NET_F_HOST_TSO4 11
#define VIRTIO_NET_F_HOST_TSO6 12
#define VIRTIO_NET_F_HOST_ECN 13
#define VIRTIO_NET_F_HOST_UFO 14
#define VIRTIO_NET_F_MRG_RXBUF 15
#define VIRTIO_NET_F_STATUS 16
#define VIRTIO_NET_F_CTRL_VQ 17
#define VIRTIO_NET_F_CTRL_RX 18
#define VIRTIO_NET_F_CTRL_VLAN 19
#define VIRTIO_NET_F_CTRL_RX_EXTRA 20
#define VIRTIO_NET_F_GUEST_ANNOUNCE 21
#define VIRTIO_NET_F_MQ 22
#define VIRTIO_NET_F_CTRL_MAC_ADDR 23
#define VIRTIO_NET_F_HASH_REPORT 57
#define VIRTIO_NET_F_RSS 60
#define VIRTIO_NET_F_RSC_EXT 61
#define VIRTIO_NET_F_STANDBY 62
#define VIRTIO_NET_F_SPEED_DUPLEX 63
#ifndef VIRTIO_NET_NO_LEGACY
#define VIRTIO_NET_F_GSO 6
#endif
#define VIRTIO_NET_S_LINK_UP 1
#define VIRTIO_NET_S_ANNOUNCE 2
#define VIRTIO_NET_RSS_HASH_TYPE_IPv4 (1 << 0)
#define VIRTIO_NET_RSS_HASH_TYPE_TCPv4 (1 << 1)
#define VIRTIO_NET_RSS_HASH_TYPE_UDPv4 (1 << 2)
#define VIRTIO_NET_RSS_HASH_TYPE_IPv6 (1 << 3)
#define VIRTIO_NET_RSS_HASH_TYPE_TCPv6 (1 << 4)
#define VIRTIO_NET_RSS_HASH_TYPE_UDPv6 (1 << 5)
#define VIRTIO_NET_RSS_HASH_TYPE_IP_EX (1 << 6)
#define VIRTIO_NET_RSS_HASH_TYPE_TCP_EX (1 << 7)
#define VIRTIO_NET_RSS_HASH_TYPE_UDP_EX (1 << 8)
struct virtio_net_config {
  __u8 mac[ETH_ALEN];
  __virtio16 status;
  __virtio16 max_virtqueue_pairs;
  __virtio16 mtu;
  __le32 speed;
  __u8 duplex;
  __u8 rss_max_key_size;
  __le16 rss_max_indirection_table_length;
  __le32 supported_hash_types;
} __attribute__((packed));
struct virtio_net_hdr_v1 {
#define VIRTIO_NET_HDR_F_NEEDS_CSUM 1
#define VIRTIO_NET_HDR_F_DATA_VALID 2
#define VIRTIO_NET_HDR_F_RSC_INFO 4
  __u8 flags;
#define VIRTIO_NET_HDR_GSO_NONE 0
#define VIRTIO_NET_HDR_GSO_TCPV4 1
#define VIRTIO_NET_HDR_GSO_UDP 3
#define VIRTIO_NET_HDR_GSO_TCPV6 4
#define VIRTIO_NET_HDR_GSO_ECN 0x80
  __u8 gso_type;
  __virtio16 hdr_len;
  __virtio16 gso_size;
  union {
    struct {
      __virtio16 csum_start;
      __virtio16 csum_offset;
    };
    struct {
      __virtio16 start;
      __virtio16 offset;
    } csum;
    struct {
      __le16 segments;
      __le16 dup_acks;
    } rsc;
  };
  __virtio16 num_buffers;
};
struct virtio_net_hdr_v1_hash {
  struct virtio_net_hdr_v1 hdr;
  __le32 hash_value;
#define VIRTIO_NET_HASH_REPORT_NONE 0
#define VIRTIO_NET_HASH_REPORT_IPv4 1
#define VIRTIO_NET_HASH_REPORT_TCPv4 2
#define VIRTIO_NET_HASH_REPORT_UDPv4 3
#define VIRTIO_NET_HASH_REPORT_IPv6 4
#define VIRTIO_NET_HASH_REPORT_TCPv6 5
#define VIRTIO_NET_HASH_REPORT_UDPv6 6
#define VIRTIO_NET_HASH_REPORT_IPv6_EX 7
#define VIRTIO_NET_HASH_REPORT_TCPv6_EX 8
#define VIRTIO_NET_HASH_REPORT_UDPv6_EX 9
  __le16 hash_report;
  __le16 padding;
};
#ifndef VIRTIO_NET_NO_LEGACY
struct virtio_net_hdr {
  __u8 flags;
  __u8 gso_type;
  __virtio16 hdr_len;
  __virtio16 gso_size;
  __virtio16 csum_start;
  __virtio16 csum_offset;
};
struct virtio_net_hdr_mrg_rxbuf {
  struct virtio_net_hdr hdr;
  __virtio16 num_buffers;
};
#endif
struct virtio_net_ctrl_hdr {
  __u8 class;
  __u8 cmd;
} __attribute__((packed));
typedef __u8 virtio_net_ctrl_ack;
#define VIRTIO_NET_OK 0
#define VIRTIO_NET_ERR 1
#define VIRTIO_NET_CTRL_RX 0
#define VIRTIO_NET_CTRL_RX_PROMISC 0
#define VIRTIO_NET_CTRL_RX_ALLMULTI 1
#define VIRTIO_NET_CTRL_RX_ALLUNI 2
#define VIRTIO_NET_CTRL_RX_NOMULTI 3
#define VIRTIO_NET_CTRL_RX_NOUNI 4
#define VIRTIO_NET_CTRL_RX_NOBCAST 5
struct virtio_net_ctrl_mac {
  __virtio32 entries;
  __u8 macs[][ETH_ALEN];
} __attribute__((packed));
#define VIRTIO_NET_CTRL_MAC 1
#define VIRTIO_NET_CTRL_MAC_TABLE_SET 0
#define VIRTIO_NET_CTRL_MAC_ADDR_SET 1
#define VIRTIO_NET_CTRL_VLAN 2
#define VIRTIO_NET_CTRL_VLAN_ADD 0
#define VIRTIO_NET_CTRL_VLAN_DEL 1
#define VIRTIO_NET_CTRL_ANNOUNCE 3
#define VIRTIO_NET_CTRL_ANNOUNCE_ACK 0
#define VIRTIO_NET_CTRL_MQ 4
struct virtio_net_ctrl_mq {
  __virtio16 virtqueue_pairs;
};
#define VIRTIO_NET_CTRL_MQ_VQ_PAIRS_SET 0
#define VIRTIO_NET_CTRL_MQ_VQ_PAIRS_MIN 1
#define VIRTIO_NET_CTRL_MQ_VQ_PAIRS_MAX 0x8000
struct virtio_net_rss_config {
  __le32 hash_types;
  __le16 indirection_table_mask;
  __le16 unclassified_queue;
  __le16 indirection_table[1];
  __le16 max_tx_vq;
  __u8 hash_key_length;
  __u8 hash_key_data[];
};
#define VIRTIO_NET_CTRL_MQ_RSS_CONFIG 1
struct virtio_net_hash_config {
  __le32 hash_types;
  __le16 reserved[4];
  __u8 hash_key_length;
  __u8 hash_key_data[];
};
#define VIRTIO_NET_CTRL_MQ_HASH_CONFIG 2
#define VIRTIO_NET_CTRL_GUEST_OFFLOADS 5
#define VIRTIO_NET_CTRL_GUEST_OFFLOADS_SET 0
#endif