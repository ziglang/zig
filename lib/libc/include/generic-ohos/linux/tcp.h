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
#ifndef _UAPI_LINUX_TCP_H
#define _UAPI_LINUX_TCP_H
#include <linux/types.h>
#include <asm/byteorder.h>
#include <linux/socket.h>
struct tcphdr {
  __be16 source;
  __be16 dest;
  __be32 seq;
  __be32 ack_seq;
#ifdef __LITTLE_ENDIAN_BITFIELD
  __u16 res1 : 4, doff : 4, fin : 1, syn : 1, rst : 1, psh : 1, ack : 1, urg : 1, ece : 1, cwr : 1;
#elif defined(__BIG_ENDIAN_BITFIELD)
  __u16 doff : 4, res1 : 4, cwr : 1, ece : 1, urg : 1, ack : 1, psh : 1, rst : 1, syn : 1, fin : 1;
#else
#error "Adjust your <asm/byteorder.h> defines"
#endif
  __be16 window;
  __sum16 check;
  __be16 urg_ptr;
};
union tcp_word_hdr {
  struct tcphdr hdr;
  __be32 words[5];
};
#define tcp_flag_word(tp) (((union tcp_word_hdr *) (tp))->words[3])
enum {
  TCP_FLAG_CWR = __constant_cpu_to_be32(0x00800000),
  TCP_FLAG_ECE = __constant_cpu_to_be32(0x00400000),
  TCP_FLAG_URG = __constant_cpu_to_be32(0x00200000),
  TCP_FLAG_ACK = __constant_cpu_to_be32(0x00100000),
  TCP_FLAG_PSH = __constant_cpu_to_be32(0x00080000),
  TCP_FLAG_RST = __constant_cpu_to_be32(0x00040000),
  TCP_FLAG_SYN = __constant_cpu_to_be32(0x00020000),
  TCP_FLAG_FIN = __constant_cpu_to_be32(0x00010000),
  TCP_RESERVED_BITS = __constant_cpu_to_be32(0x0F000000),
  TCP_DATA_OFFSET = __constant_cpu_to_be32(0xF0000000)
};
#define TCP_MSS_DEFAULT 536U
#define TCP_MSS_DESIRED 1220U
#define TCP_NODELAY 1
#define TCP_MAXSEG 2
#define TCP_CORK 3
#define TCP_KEEPIDLE 4
#define TCP_KEEPINTVL 5
#define TCP_KEEPCNT 6
#define TCP_SYNCNT 7
#define TCP_LINGER2 8
#define TCP_DEFER_ACCEPT 9
#define TCP_WINDOW_CLAMP 10
#define TCP_INFO 11
#define TCP_QUICKACK 12
#define TCP_CONGESTION 13
#define TCP_MD5SIG 14
#define TCP_THIN_LINEAR_TIMEOUTS 16
#define TCP_THIN_DUPACK 17
#define TCP_USER_TIMEOUT 18
#define TCP_REPAIR 19
#define TCP_REPAIR_QUEUE 20
#define TCP_QUEUE_SEQ 21
#define TCP_REPAIR_OPTIONS 22
#define TCP_FASTOPEN 23
#define TCP_TIMESTAMP 24
#define TCP_NOTSENT_LOWAT 25
#define TCP_CC_INFO 26
#define TCP_SAVE_SYN 27
#define TCP_SAVED_SYN 28
#define TCP_REPAIR_WINDOW 29
#define TCP_FASTOPEN_CONNECT 30
#define TCP_ULP 31
#define TCP_MD5SIG_EXT 32
#define TCP_FASTOPEN_KEY 33
#define TCP_FASTOPEN_NO_COOKIE 34
#define TCP_ZEROCOPY_RECEIVE 35
#define TCP_INQ 36
#define TCP_CM_INQ TCP_INQ
#define TCP_TX_DELAY 37
#define TCP_REPAIR_ON 1
#define TCP_REPAIR_OFF 0
#define TCP_REPAIR_OFF_NO_WP - 1
struct tcp_repair_opt {
  __u32 opt_code;
  __u32 opt_val;
};
struct tcp_repair_window {
  __u32 snd_wl1;
  __u32 snd_wnd;
  __u32 max_window;
  __u32 rcv_wnd;
  __u32 rcv_wup;
};
enum {
  TCP_NO_QUEUE,
  TCP_RECV_QUEUE,
  TCP_SEND_QUEUE,
  TCP_QUEUES_NR,
};
enum tcp_fastopen_client_fail {
  TFO_STATUS_UNSPEC,
  TFO_COOKIE_UNAVAILABLE,
  TFO_DATA_NOT_ACKED,
  TFO_SYN_RETRANSMITTED,
};
#define TCPI_OPT_TIMESTAMPS 1
#define TCPI_OPT_SACK 2
#define TCPI_OPT_WSCALE 4
#define TCPI_OPT_ECN 8
#define TCPI_OPT_ECN_SEEN 16
#define TCPI_OPT_SYN_DATA 32
enum tcp_ca_state {
  TCP_CA_Open = 0,
#define TCPF_CA_Open (1 << TCP_CA_Open)
  TCP_CA_Disorder = 1,
#define TCPF_CA_Disorder (1 << TCP_CA_Disorder)
  TCP_CA_CWR = 2,
#define TCPF_CA_CWR (1 << TCP_CA_CWR)
  TCP_CA_Recovery = 3,
#define TCPF_CA_Recovery (1 << TCP_CA_Recovery)
  TCP_CA_Loss = 4
#define TCPF_CA_Loss (1 << TCP_CA_Loss)
};
struct tcp_info {
  __u8 tcpi_state;
  __u8 tcpi_ca_state;
  __u8 tcpi_retransmits;
  __u8 tcpi_probes;
  __u8 tcpi_backoff;
  __u8 tcpi_options;
  __u8 tcpi_snd_wscale : 4, tcpi_rcv_wscale : 4;
  __u8 tcpi_delivery_rate_app_limited : 1, tcpi_fastopen_client_fail : 2;
  __u32 tcpi_rto;
  __u32 tcpi_ato;
  __u32 tcpi_snd_mss;
  __u32 tcpi_rcv_mss;
  __u32 tcpi_unacked;
  __u32 tcpi_sacked;
  __u32 tcpi_lost;
  __u32 tcpi_retrans;
  __u32 tcpi_fackets;
  __u32 tcpi_last_data_sent;
  __u32 tcpi_last_ack_sent;
  __u32 tcpi_last_data_recv;
  __u32 tcpi_last_ack_recv;
  __u32 tcpi_pmtu;
  __u32 tcpi_rcv_ssthresh;
  __u32 tcpi_rtt;
  __u32 tcpi_rttvar;
  __u32 tcpi_snd_ssthresh;
  __u32 tcpi_snd_cwnd;
  __u32 tcpi_advmss;
  __u32 tcpi_reordering;
  __u32 tcpi_rcv_rtt;
  __u32 tcpi_rcv_space;
  __u32 tcpi_total_retrans;
  __u64 tcpi_pacing_rate;
  __u64 tcpi_max_pacing_rate;
  __u64 tcpi_bytes_acked;
  __u64 tcpi_bytes_received;
  __u32 tcpi_segs_out;
  __u32 tcpi_segs_in;
  __u32 tcpi_notsent_bytes;
  __u32 tcpi_min_rtt;
  __u32 tcpi_data_segs_in;
  __u32 tcpi_data_segs_out;
  __u64 tcpi_delivery_rate;
  __u64 tcpi_busy_time;
  __u64 tcpi_rwnd_limited;
  __u64 tcpi_sndbuf_limited;
  __u32 tcpi_delivered;
  __u32 tcpi_delivered_ce;
  __u64 tcpi_bytes_sent;
  __u64 tcpi_bytes_retrans;
  __u32 tcpi_dsack_dups;
  __u32 tcpi_reord_seen;
  __u32 tcpi_rcv_ooopack;
  __u32 tcpi_snd_wnd;
};
enum {
  TCP_NLA_PAD,
  TCP_NLA_BUSY,
  TCP_NLA_RWND_LIMITED,
  TCP_NLA_SNDBUF_LIMITED,
  TCP_NLA_DATA_SEGS_OUT,
  TCP_NLA_TOTAL_RETRANS,
  TCP_NLA_PACING_RATE,
  TCP_NLA_DELIVERY_RATE,
  TCP_NLA_SND_CWND,
  TCP_NLA_REORDERING,
  TCP_NLA_MIN_RTT,
  TCP_NLA_RECUR_RETRANS,
  TCP_NLA_DELIVERY_RATE_APP_LMT,
  TCP_NLA_SNDQ_SIZE,
  TCP_NLA_CA_STATE,
  TCP_NLA_SND_SSTHRESH,
  TCP_NLA_DELIVERED,
  TCP_NLA_DELIVERED_CE,
  TCP_NLA_BYTES_SENT,
  TCP_NLA_BYTES_RETRANS,
  TCP_NLA_DSACK_DUPS,
  TCP_NLA_REORD_SEEN,
  TCP_NLA_SRTT,
  TCP_NLA_TIMEOUT_REHASH,
  TCP_NLA_BYTES_NOTSENT,
  TCP_NLA_EDT,
};
#define TCP_MD5SIG_MAXKEYLEN 80
#define TCP_MD5SIG_FLAG_PREFIX 0x1
#define TCP_MD5SIG_FLAG_IFINDEX 0x2
struct tcp_md5sig {
  struct sockaddr_storage tcpm_addr;
  __u8 tcpm_flags;
  __u8 tcpm_prefixlen;
  __u16 tcpm_keylen;
  int tcpm_ifindex;
  __u8 tcpm_key[TCP_MD5SIG_MAXKEYLEN];
};
struct tcp_diag_md5sig {
  __u8 tcpm_family;
  __u8 tcpm_prefixlen;
  __u16 tcpm_keylen;
  __be32 tcpm_addr[4];
  __u8 tcpm_key[TCP_MD5SIG_MAXKEYLEN];
};
struct tcp_zerocopy_receive {
  __u64 address;
  __u32 length;
  __u32 recv_skip_hint;
  __u32 inq;
  __s32 err;
};
#endif