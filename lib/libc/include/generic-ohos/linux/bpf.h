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
#ifndef _UAPI__LINUX_BPF_H__
#define _UAPI__LINUX_BPF_H__
#include <linux/types.h>
#include <linux/bpf_common.h>
#define BPF_JMP32 0x06
#define BPF_ALU64 0x07
#define BPF_DW 0x18
#define BPF_XADD 0xc0
#define BPF_MOV 0xb0
#define BPF_ARSH 0xc0
#define BPF_END 0xd0
#define BPF_TO_LE 0x00
#define BPF_TO_BE 0x08
#define BPF_FROM_LE BPF_TO_LE
#define BPF_FROM_BE BPF_TO_BE
#define BPF_JNE 0x50
#define BPF_JLT 0xa0
#define BPF_JLE 0xb0
#define BPF_JSGT 0x60
#define BPF_JSGE 0x70
#define BPF_JSLT 0xc0
#define BPF_JSLE 0xd0
#define BPF_CALL 0x80
#define BPF_EXIT 0x90
enum {
  BPF_REG_0 = 0,
  BPF_REG_1,
  BPF_REG_2,
  BPF_REG_3,
  BPF_REG_4,
  BPF_REG_5,
  BPF_REG_6,
  BPF_REG_7,
  BPF_REG_8,
  BPF_REG_9,
  BPF_REG_10,
  __MAX_BPF_REG,
};
#define MAX_BPF_REG __MAX_BPF_REG
struct bpf_insn {
  __u8 code;
  __u8 dst_reg : 4;
  __u8 src_reg : 4;
  __s16 off;
  __s32 imm;
};
struct bpf_lpm_trie_key {
  __u32 prefixlen;
  __u8 data[0];
};
struct bpf_cgroup_storage_key {
  __u64 cgroup_inode_id;
  __u32 attach_type;
};
union bpf_iter_link_info {
  struct {
    __u32 map_fd;
  } map;
};
enum bpf_cmd {
  BPF_MAP_CREATE,
  BPF_MAP_LOOKUP_ELEM,
  BPF_MAP_UPDATE_ELEM,
  BPF_MAP_DELETE_ELEM,
  BPF_MAP_GET_NEXT_KEY,
  BPF_PROG_LOAD,
  BPF_OBJ_PIN,
  BPF_OBJ_GET,
  BPF_PROG_ATTACH,
  BPF_PROG_DETACH,
  BPF_PROG_TEST_RUN,
  BPF_PROG_GET_NEXT_ID,
  BPF_MAP_GET_NEXT_ID,
  BPF_PROG_GET_FD_BY_ID,
  BPF_MAP_GET_FD_BY_ID,
  BPF_OBJ_GET_INFO_BY_FD,
  BPF_PROG_QUERY,
  BPF_RAW_TRACEPOINT_OPEN,
  BPF_BTF_LOAD,
  BPF_BTF_GET_FD_BY_ID,
  BPF_TASK_FD_QUERY,
  BPF_MAP_LOOKUP_AND_DELETE_ELEM,
  BPF_MAP_FREEZE,
  BPF_BTF_GET_NEXT_ID,
  BPF_MAP_LOOKUP_BATCH,
  BPF_MAP_LOOKUP_AND_DELETE_BATCH,
  BPF_MAP_UPDATE_BATCH,
  BPF_MAP_DELETE_BATCH,
  BPF_LINK_CREATE,
  BPF_LINK_UPDATE,
  BPF_LINK_GET_FD_BY_ID,
  BPF_LINK_GET_NEXT_ID,
  BPF_ENABLE_STATS,
  BPF_ITER_CREATE,
  BPF_LINK_DETACH,
  BPF_PROG_BIND_MAP,
};
enum bpf_map_type {
  BPF_MAP_TYPE_UNSPEC,
  BPF_MAP_TYPE_HASH,
  BPF_MAP_TYPE_ARRAY,
  BPF_MAP_TYPE_PROG_ARRAY,
  BPF_MAP_TYPE_PERF_EVENT_ARRAY,
  BPF_MAP_TYPE_PERCPU_HASH,
  BPF_MAP_TYPE_PERCPU_ARRAY,
  BPF_MAP_TYPE_STACK_TRACE,
  BPF_MAP_TYPE_CGROUP_ARRAY,
  BPF_MAP_TYPE_LRU_HASH,
  BPF_MAP_TYPE_LRU_PERCPU_HASH,
  BPF_MAP_TYPE_LPM_TRIE,
  BPF_MAP_TYPE_ARRAY_OF_MAPS,
  BPF_MAP_TYPE_HASH_OF_MAPS,
  BPF_MAP_TYPE_DEVMAP,
  BPF_MAP_TYPE_SOCKMAP,
  BPF_MAP_TYPE_CPUMAP,
  BPF_MAP_TYPE_XSKMAP,
  BPF_MAP_TYPE_SOCKHASH,
  BPF_MAP_TYPE_CGROUP_STORAGE,
  BPF_MAP_TYPE_REUSEPORT_SOCKARRAY,
  BPF_MAP_TYPE_PERCPU_CGROUP_STORAGE,
  BPF_MAP_TYPE_QUEUE,
  BPF_MAP_TYPE_STACK,
  BPF_MAP_TYPE_SK_STORAGE,
  BPF_MAP_TYPE_DEVMAP_HASH,
  BPF_MAP_TYPE_STRUCT_OPS,
  BPF_MAP_TYPE_RINGBUF,
  BPF_MAP_TYPE_INODE_STORAGE,
};
enum bpf_prog_type {
  BPF_PROG_TYPE_UNSPEC,
  BPF_PROG_TYPE_SOCKET_FILTER,
  BPF_PROG_TYPE_KPROBE,
  BPF_PROG_TYPE_SCHED_CLS,
  BPF_PROG_TYPE_SCHED_ACT,
  BPF_PROG_TYPE_TRACEPOINT,
  BPF_PROG_TYPE_XDP,
  BPF_PROG_TYPE_PERF_EVENT,
  BPF_PROG_TYPE_CGROUP_SKB,
  BPF_PROG_TYPE_CGROUP_SOCK,
  BPF_PROG_TYPE_LWT_IN,
  BPF_PROG_TYPE_LWT_OUT,
  BPF_PROG_TYPE_LWT_XMIT,
  BPF_PROG_TYPE_SOCK_OPS,
  BPF_PROG_TYPE_SK_SKB,
  BPF_PROG_TYPE_CGROUP_DEVICE,
  BPF_PROG_TYPE_SK_MSG,
  BPF_PROG_TYPE_RAW_TRACEPOINT,
  BPF_PROG_TYPE_CGROUP_SOCK_ADDR,
  BPF_PROG_TYPE_LWT_SEG6LOCAL,
  BPF_PROG_TYPE_LIRC_MODE2,
  BPF_PROG_TYPE_SK_REUSEPORT,
  BPF_PROG_TYPE_FLOW_DISSECTOR,
  BPF_PROG_TYPE_CGROUP_SYSCTL,
  BPF_PROG_TYPE_RAW_TRACEPOINT_WRITABLE,
  BPF_PROG_TYPE_CGROUP_SOCKOPT,
  BPF_PROG_TYPE_TRACING,
  BPF_PROG_TYPE_STRUCT_OPS,
  BPF_PROG_TYPE_EXT,
  BPF_PROG_TYPE_LSM,
  BPF_PROG_TYPE_SK_LOOKUP,
};
enum bpf_attach_type {
  BPF_CGROUP_INET_INGRESS,
  BPF_CGROUP_INET_EGRESS,
  BPF_CGROUP_INET_SOCK_CREATE,
  BPF_CGROUP_SOCK_OPS,
  BPF_SK_SKB_STREAM_PARSER,
  BPF_SK_SKB_STREAM_VERDICT,
  BPF_CGROUP_DEVICE,
  BPF_SK_MSG_VERDICT,
  BPF_CGROUP_INET4_BIND,
  BPF_CGROUP_INET6_BIND,
  BPF_CGROUP_INET4_CONNECT,
  BPF_CGROUP_INET6_CONNECT,
  BPF_CGROUP_INET4_POST_BIND,
  BPF_CGROUP_INET6_POST_BIND,
  BPF_CGROUP_UDP4_SENDMSG,
  BPF_CGROUP_UDP6_SENDMSG,
  BPF_LIRC_MODE2,
  BPF_FLOW_DISSECTOR,
  BPF_CGROUP_SYSCTL,
  BPF_CGROUP_UDP4_RECVMSG,
  BPF_CGROUP_UDP6_RECVMSG,
  BPF_CGROUP_GETSOCKOPT,
  BPF_CGROUP_SETSOCKOPT,
  BPF_TRACE_RAW_TP,
  BPF_TRACE_FENTRY,
  BPF_TRACE_FEXIT,
  BPF_MODIFY_RETURN,
  BPF_LSM_MAC,
  BPF_TRACE_ITER,
  BPF_CGROUP_INET4_GETPEERNAME,
  BPF_CGROUP_INET6_GETPEERNAME,
  BPF_CGROUP_INET4_GETSOCKNAME,
  BPF_CGROUP_INET6_GETSOCKNAME,
  BPF_XDP_DEVMAP,
  BPF_CGROUP_INET_SOCK_RELEASE,
  BPF_XDP_CPUMAP,
  BPF_SK_LOOKUP,
  BPF_XDP,
  __MAX_BPF_ATTACH_TYPE
};
#define MAX_BPF_ATTACH_TYPE __MAX_BPF_ATTACH_TYPE
enum bpf_link_type {
  BPF_LINK_TYPE_UNSPEC = 0,
  BPF_LINK_TYPE_RAW_TRACEPOINT = 1,
  BPF_LINK_TYPE_TRACING = 2,
  BPF_LINK_TYPE_CGROUP = 3,
  BPF_LINK_TYPE_ITER = 4,
  BPF_LINK_TYPE_NETNS = 5,
  BPF_LINK_TYPE_XDP = 6,
  MAX_BPF_LINK_TYPE,
};
#define BPF_F_ALLOW_OVERRIDE (1U << 0)
#define BPF_F_ALLOW_MULTI (1U << 1)
#define BPF_F_REPLACE (1U << 2)
#define BPF_F_STRICT_ALIGNMENT (1U << 0)
#define BPF_F_ANY_ALIGNMENT (1U << 1)
#define BPF_F_TEST_RND_HI32 (1U << 2)
#define BPF_F_TEST_STATE_FREQ (1U << 3)
#define BPF_F_SLEEPABLE (1U << 4)
#define BPF_PSEUDO_MAP_FD 1
#define BPF_PSEUDO_MAP_VALUE 2
#define BPF_PSEUDO_BTF_ID 3
#define BPF_PSEUDO_CALL 1
enum {
  BPF_ANY = 0,
  BPF_NOEXIST = 1,
  BPF_EXIST = 2,
  BPF_F_LOCK = 4,
};
enum {
  BPF_F_NO_PREALLOC = (1U << 0),
  BPF_F_NO_COMMON_LRU = (1U << 1),
  BPF_F_NUMA_NODE = (1U << 2),
  BPF_F_RDONLY = (1U << 3),
  BPF_F_WRONLY = (1U << 4),
  BPF_F_STACK_BUILD_ID = (1U << 5),
  BPF_F_ZERO_SEED = (1U << 6),
  BPF_F_RDONLY_PROG = (1U << 7),
  BPF_F_WRONLY_PROG = (1U << 8),
  BPF_F_CLONE = (1U << 9),
  BPF_F_MMAPABLE = (1U << 10),
  BPF_F_PRESERVE_ELEMS = (1U << 11),
  BPF_F_INNER_MAP = (1U << 12),
};
#define BPF_F_QUERY_EFFECTIVE (1U << 0)
#define BPF_F_TEST_RUN_ON_CPU (1U << 0)
enum bpf_stats_type {
  BPF_STATS_RUN_TIME = 0,
};
enum bpf_stack_build_id_status {
  BPF_STACK_BUILD_ID_EMPTY = 0,
  BPF_STACK_BUILD_ID_VALID = 1,
  BPF_STACK_BUILD_ID_IP = 2,
};
#define BPF_BUILD_ID_SIZE 20
struct bpf_stack_build_id {
  __s32 status;
  unsigned char build_id[BPF_BUILD_ID_SIZE];
  union {
    __u64 offset;
    __u64 ip;
  };
};
#define BPF_OBJ_NAME_LEN 16U
union bpf_attr {
  struct {
    __u32 map_type;
    __u32 key_size;
    __u32 value_size;
    __u32 max_entries;
    __u32 map_flags;
    __u32 inner_map_fd;
    __u32 numa_node;
    char map_name[BPF_OBJ_NAME_LEN];
    __u32 map_ifindex;
    __u32 btf_fd;
    __u32 btf_key_type_id;
    __u32 btf_value_type_id;
    __u32 btf_vmlinux_value_type_id;
  };
  struct {
    __u32 map_fd;
    __aligned_u64 key;
    union {
      __aligned_u64 value;
      __aligned_u64 next_key;
    };
    __u64 flags;
  };
  struct {
    __aligned_u64 in_batch;
    __aligned_u64 out_batch;
    __aligned_u64 keys;
    __aligned_u64 values;
    __u32 count;
    __u32 map_fd;
    __u64 elem_flags;
    __u64 flags;
  } batch;
  struct {
    __u32 prog_type;
    __u32 insn_cnt;
    __aligned_u64 insns;
    __aligned_u64 license;
    __u32 log_level;
    __u32 log_size;
    __aligned_u64 log_buf;
    __u32 kern_version;
    __u32 prog_flags;
    char prog_name[BPF_OBJ_NAME_LEN];
    __u32 prog_ifindex;
    __u32 expected_attach_type;
    __u32 prog_btf_fd;
    __u32 func_info_rec_size;
    __aligned_u64 func_info;
    __u32 func_info_cnt;
    __u32 line_info_rec_size;
    __aligned_u64 line_info;
    __u32 line_info_cnt;
    __u32 attach_btf_id;
    __u32 attach_prog_fd;
  };
  struct {
    __aligned_u64 pathname;
    __u32 bpf_fd;
    __u32 file_flags;
  };
  struct {
    __u32 target_fd;
    __u32 attach_bpf_fd;
    __u32 attach_type;
    __u32 attach_flags;
    __u32 replace_bpf_fd;
  };
  struct {
    __u32 prog_fd;
    __u32 retval;
    __u32 data_size_in;
    __u32 data_size_out;
    __aligned_u64 data_in;
    __aligned_u64 data_out;
    __u32 repeat;
    __u32 duration;
    __u32 ctx_size_in;
    __u32 ctx_size_out;
    __aligned_u64 ctx_in;
    __aligned_u64 ctx_out;
    __u32 flags;
    __u32 cpu;
  } test;
  struct {
    union {
      __u32 start_id;
      __u32 prog_id;
      __u32 map_id;
      __u32 btf_id;
      __u32 link_id;
    };
    __u32 next_id;
    __u32 open_flags;
  };
  struct {
    __u32 bpf_fd;
    __u32 info_len;
    __aligned_u64 info;
  } info;
  struct {
    __u32 target_fd;
    __u32 attach_type;
    __u32 query_flags;
    __u32 attach_flags;
    __aligned_u64 prog_ids;
    __u32 prog_cnt;
  } query;
  struct {
    __u64 name;
    __u32 prog_fd;
  } raw_tracepoint;
  struct {
    __aligned_u64 btf;
    __aligned_u64 btf_log_buf;
    __u32 btf_size;
    __u32 btf_log_size;
    __u32 btf_log_level;
  };
  struct {
    __u32 pid;
    __u32 fd;
    __u32 flags;
    __u32 buf_len;
    __aligned_u64 buf;
    __u32 prog_id;
    __u32 fd_type;
    __u64 probe_offset;
    __u64 probe_addr;
  } task_fd_query;
  struct {
    __u32 prog_fd;
    union {
      __u32 target_fd;
      __u32 target_ifindex;
    };
    __u32 attach_type;
    __u32 flags;
    union {
      __u32 target_btf_id;
      struct {
        __aligned_u64 iter_info;
        __u32 iter_info_len;
      };
    };
  } link_create;
  struct {
    __u32 link_fd;
    __u32 new_prog_fd;
    __u32 flags;
    __u32 old_prog_fd;
  } link_update;
  struct {
    __u32 link_fd;
  } link_detach;
  struct {
    __u32 type;
  } enable_stats;
  struct {
    __u32 link_fd;
    __u32 flags;
  } iter_create;
  struct {
    __u32 prog_fd;
    __u32 map_fd;
    __u32 flags;
  } prog_bind_map;
} __attribute__((aligned(8)));
#define __BPF_FUNC_MAPPER(FN) FN(unspec), FN(map_lookup_elem), FN(map_update_elem), FN(map_delete_elem), FN(probe_read), FN(ktime_get_ns), FN(trace_printk), FN(get_prandom_u32), FN(get_smp_processor_id), FN(skb_store_bytes), FN(l3_csum_replace), FN(l4_csum_replace), FN(tail_call), FN(clone_redirect), FN(get_current_pid_tgid), FN(get_current_uid_gid), FN(get_current_comm), FN(get_cgroup_classid), FN(skb_vlan_push), FN(skb_vlan_pop), FN(skb_get_tunnel_key), FN(skb_set_tunnel_key), FN(perf_event_read), FN(redirect), FN(get_route_realm), FN(perf_event_output), FN(skb_load_bytes), FN(get_stackid), FN(csum_diff), FN(skb_get_tunnel_opt), FN(skb_set_tunnel_opt), FN(skb_change_proto), FN(skb_change_type), FN(skb_under_cgroup), FN(get_hash_recalc), FN(get_current_task), FN(probe_write_user), FN(current_task_under_cgroup), FN(skb_change_tail), FN(skb_pull_data), FN(csum_update), FN(set_hash_invalid), FN(get_numa_node_id), FN(skb_change_head), FN(xdp_adjust_head), FN(probe_read_str), FN(get_socket_cookie), FN(get_socket_uid), FN(set_hash), FN(setsockopt), FN(skb_adjust_room), FN(redirect_map), FN(sk_redirect_map), FN(sock_map_update), FN(xdp_adjust_meta), FN(perf_event_read_value), FN(perf_prog_read_value), FN(getsockopt), FN(override_return), FN(sock_ops_cb_flags_set), FN(msg_redirect_map), FN(msg_apply_bytes), FN(msg_cork_bytes), FN(msg_pull_data), FN(bind), FN(xdp_adjust_tail), FN(skb_get_xfrm_state), FN(get_stack), FN(skb_load_bytes_relative), FN(fib_lookup), FN(sock_hash_update), FN(msg_redirect_hash), FN(sk_redirect_hash), FN(lwt_push_encap), FN(lwt_seg6_store_bytes), FN(lwt_seg6_adjust_srh), FN(lwt_seg6_action), FN(rc_repeat), FN(rc_keydown), FN(skb_cgroup_id), FN(get_current_cgroup_id), FN(get_local_storage), FN(sk_select_reuseport), FN(skb_ancestor_cgroup_id), FN(sk_lookup_tcp), FN(sk_lookup_udp), FN(sk_release), FN(map_push_elem), FN(map_pop_elem), FN(map_peek_elem), FN(msg_push_data), FN(msg_pop_data), FN(rc_pointer_rel), FN(spin_lock), FN(spin_unlock), FN(sk_fullsock), FN(tcp_sock), FN(skb_ecn_set_ce), FN(get_listener_sock), FN(skc_lookup_tcp), FN(tcp_check_syncookie), FN(sysctl_get_name), FN(sysctl_get_current_value), FN(sysctl_get_new_value), FN(sysctl_set_new_value), FN(strtol), FN(strtoul), FN(sk_storage_get), FN(sk_storage_delete), FN(send_signal), FN(tcp_gen_syncookie), FN(skb_output), FN(probe_read_user), FN(probe_read_kernel), FN(probe_read_user_str), FN(probe_read_kernel_str), FN(tcp_send_ack), FN(send_signal_thread), FN(jiffies64), FN(read_branch_records), FN(get_ns_current_pid_tgid), FN(xdp_output), FN(get_netns_cookie), FN(get_current_ancestor_cgroup_id), FN(sk_assign), FN(ktime_get_boot_ns), FN(seq_printf), FN(seq_write), FN(sk_cgroup_id), FN(sk_ancestor_cgroup_id), FN(ringbuf_output), FN(ringbuf_reserve), FN(ringbuf_submit), FN(ringbuf_discard), FN(ringbuf_query), FN(csum_level), FN(skc_to_tcp6_sock), FN(skc_to_tcp_sock), FN(skc_to_tcp_timewait_sock), FN(skc_to_tcp_request_sock), FN(skc_to_udp6_sock), FN(get_task_stack), FN(load_hdr_opt), FN(store_hdr_opt), FN(reserve_hdr_opt), FN(inode_storage_get), FN(inode_storage_delete), FN(d_path), FN(copy_from_user), FN(snprintf_btf), FN(seq_printf_btf), FN(skb_cgroup_classid), FN(redirect_neigh), FN(per_cpu_ptr), FN(this_cpu_ptr), FN(redirect_peer),
#define __BPF_ENUM_FN(x) BPF_FUNC_ ##x
enum bpf_func_id {
  __BPF_FUNC_MAPPER(__BPF_ENUM_FN) __BPF_FUNC_MAX_ID,
};
#undef __BPF_ENUM_FN
enum {
  BPF_F_RECOMPUTE_CSUM = (1ULL << 0),
  BPF_F_INVALIDATE_HASH = (1ULL << 1),
};
enum {
  BPF_F_HDR_FIELD_MASK = 0xfULL,
};
enum {
  BPF_F_PSEUDO_HDR = (1ULL << 4),
  BPF_F_MARK_MANGLED_0 = (1ULL << 5),
  BPF_F_MARK_ENFORCE = (1ULL << 6),
};
enum {
  BPF_F_INGRESS = (1ULL << 0),
};
enum {
  BPF_F_TUNINFO_IPV6 = (1ULL << 0),
};
enum {
  BPF_F_SKIP_FIELD_MASK = 0xffULL,
  BPF_F_USER_STACK = (1ULL << 8),
  BPF_F_FAST_STACK_CMP = (1ULL << 9),
  BPF_F_REUSE_STACKID = (1ULL << 10),
  BPF_F_USER_BUILD_ID = (1ULL << 11),
};
enum {
  BPF_F_ZERO_CSUM_TX = (1ULL << 1),
  BPF_F_DONT_FRAGMENT = (1ULL << 2),
  BPF_F_SEQ_NUMBER = (1ULL << 3),
};
enum {
  BPF_F_INDEX_MASK = 0xffffffffULL,
  BPF_F_CURRENT_CPU = BPF_F_INDEX_MASK,
  BPF_F_CTXLEN_MASK = (0xfffffULL << 32),
};
enum {
  BPF_F_CURRENT_NETNS = (- 1L),
};
enum {
  BPF_CSUM_LEVEL_QUERY,
  BPF_CSUM_LEVEL_INC,
  BPF_CSUM_LEVEL_DEC,
  BPF_CSUM_LEVEL_RESET,
};
enum {
  BPF_F_ADJ_ROOM_FIXED_GSO = (1ULL << 0),
  BPF_F_ADJ_ROOM_ENCAP_L3_IPV4 = (1ULL << 1),
  BPF_F_ADJ_ROOM_ENCAP_L3_IPV6 = (1ULL << 2),
  BPF_F_ADJ_ROOM_ENCAP_L4_GRE = (1ULL << 3),
  BPF_F_ADJ_ROOM_ENCAP_L4_UDP = (1ULL << 4),
  BPF_F_ADJ_ROOM_NO_CSUM_RESET = (1ULL << 5),
};
enum {
  BPF_ADJ_ROOM_ENCAP_L2_MASK = 0xff,
  BPF_ADJ_ROOM_ENCAP_L2_SHIFT = 56,
};
#define BPF_F_ADJ_ROOM_ENCAP_L2(len) (((__u64) len & BPF_ADJ_ROOM_ENCAP_L2_MASK) << BPF_ADJ_ROOM_ENCAP_L2_SHIFT)
enum {
  BPF_F_SYSCTL_BASE_NAME = (1ULL << 0),
};
enum {
  BPF_LOCAL_STORAGE_GET_F_CREATE = (1ULL << 0),
  BPF_SK_STORAGE_GET_F_CREATE = BPF_LOCAL_STORAGE_GET_F_CREATE,
};
enum {
  BPF_F_GET_BRANCH_RECORDS_SIZE = (1ULL << 0),
};
enum {
  BPF_RB_NO_WAKEUP = (1ULL << 0),
  BPF_RB_FORCE_WAKEUP = (1ULL << 1),
};
enum {
  BPF_RB_AVAIL_DATA = 0,
  BPF_RB_RING_SIZE = 1,
  BPF_RB_CONS_POS = 2,
  BPF_RB_PROD_POS = 3,
};
enum {
  BPF_RINGBUF_BUSY_BIT = (1U << 31),
  BPF_RINGBUF_DISCARD_BIT = (1U << 30),
  BPF_RINGBUF_HDR_SZ = 8,
};
enum {
  BPF_SK_LOOKUP_F_REPLACE = (1ULL << 0),
  BPF_SK_LOOKUP_F_NO_REUSEPORT = (1ULL << 1),
};
enum bpf_adj_room_mode {
  BPF_ADJ_ROOM_NET,
  BPF_ADJ_ROOM_MAC,
};
enum bpf_hdr_start_off {
  BPF_HDR_START_MAC,
  BPF_HDR_START_NET,
};
enum bpf_lwt_encap_mode {
  BPF_LWT_ENCAP_SEG6,
  BPF_LWT_ENCAP_SEG6_INLINE,
  BPF_LWT_ENCAP_IP,
};
#define __bpf_md_ptr(type,name) union { type name; __u64 : 64; \
} __attribute__((aligned(8)))
struct __sk_buff {
  __u32 len;
  __u32 pkt_type;
  __u32 mark;
  __u32 queue_mapping;
  __u32 protocol;
  __u32 vlan_present;
  __u32 vlan_tci;
  __u32 vlan_proto;
  __u32 priority;
  __u32 ingress_ifindex;
  __u32 ifindex;
  __u32 tc_index;
  __u32 cb[5];
  __u32 hash;
  __u32 tc_classid;
  __u32 data;
  __u32 data_end;
  __u32 napi_id;
  __u32 family;
  __u32 remote_ip4;
  __u32 local_ip4;
  __u32 remote_ip6[4];
  __u32 local_ip6[4];
  __u32 remote_port;
  __u32 local_port;
  __u32 data_meta;
  __bpf_md_ptr(struct bpf_flow_keys *, flow_keys);
  __u64 tstamp;
  __u32 wire_len;
  __u32 gso_segs;
  __bpf_md_ptr(struct bpf_sock *, sk);
  __u32 gso_size;
};
struct bpf_tunnel_key {
  __u32 tunnel_id;
  union {
    __u32 remote_ipv4;
    __u32 remote_ipv6[4];
  };
  __u8 tunnel_tos;
  __u8 tunnel_ttl;
  __u16 tunnel_ext;
  __u32 tunnel_label;
};
struct bpf_xfrm_state {
  __u32 reqid;
  __u32 spi;
  __u16 family;
  __u16 ext;
  union {
    __u32 remote_ipv4;
    __u32 remote_ipv6[4];
  };
};
enum bpf_ret_code {
  BPF_OK = 0,
  BPF_DROP = 2,
  BPF_REDIRECT = 7,
  BPF_LWT_REROUTE = 128,
};
struct bpf_sock {
  __u32 bound_dev_if;
  __u32 family;
  __u32 type;
  __u32 protocol;
  __u32 mark;
  __u32 priority;
  __u32 src_ip4;
  __u32 src_ip6[4];
  __u32 src_port;
  __u32 dst_port;
  __u32 dst_ip4;
  __u32 dst_ip6[4];
  __u32 state;
  __s32 rx_queue_mapping;
};
struct bpf_tcp_sock {
  __u32 snd_cwnd;
  __u32 srtt_us;
  __u32 rtt_min;
  __u32 snd_ssthresh;
  __u32 rcv_nxt;
  __u32 snd_nxt;
  __u32 snd_una;
  __u32 mss_cache;
  __u32 ecn_flags;
  __u32 rate_delivered;
  __u32 rate_interval_us;
  __u32 packets_out;
  __u32 retrans_out;
  __u32 total_retrans;
  __u32 segs_in;
  __u32 data_segs_in;
  __u32 segs_out;
  __u32 data_segs_out;
  __u32 lost_out;
  __u32 sacked_out;
  __u64 bytes_received;
  __u64 bytes_acked;
  __u32 dsack_dups;
  __u32 delivered;
  __u32 delivered_ce;
  __u32 icsk_retransmits;
};
struct bpf_sock_tuple {
  union {
    struct {
      __be32 saddr;
      __be32 daddr;
      __be16 sport;
      __be16 dport;
    } ipv4;
    struct {
      __be32 saddr[4];
      __be32 daddr[4];
      __be16 sport;
      __be16 dport;
    } ipv6;
  };
};
struct bpf_xdp_sock {
  __u32 queue_id;
};
#define XDP_PACKET_HEADROOM 256
enum xdp_action {
  XDP_ABORTED = 0,
  XDP_DROP,
  XDP_PASS,
  XDP_TX,
  XDP_REDIRECT,
};
struct xdp_md {
  __u32 data;
  __u32 data_end;
  __u32 data_meta;
  __u32 ingress_ifindex;
  __u32 rx_queue_index;
  __u32 egress_ifindex;
};
struct bpf_devmap_val {
  __u32 ifindex;
  union {
    int fd;
    __u32 id;
  } bpf_prog;
};
struct bpf_cpumap_val {
  __u32 qsize;
  union {
    int fd;
    __u32 id;
  } bpf_prog;
};
enum sk_action {
  SK_DROP = 0,
  SK_PASS,
};
struct sk_msg_md {
  __bpf_md_ptr(void *, data);
  __bpf_md_ptr(void *, data_end);
  __u32 family;
  __u32 remote_ip4;
  __u32 local_ip4;
  __u32 remote_ip6[4];
  __u32 local_ip6[4];
  __u32 remote_port;
  __u32 local_port;
  __u32 size;
  __bpf_md_ptr(struct bpf_sock *, sk);
};
struct sk_reuseport_md {
  __bpf_md_ptr(void *, data);
  __bpf_md_ptr(void *, data_end);
  __u32 len;
  __u32 eth_protocol;
  __u32 ip_protocol;
  __u32 bind_inany;
  __u32 hash;
};
#define BPF_TAG_SIZE 8
struct bpf_prog_info {
  __u32 type;
  __u32 id;
  __u8 tag[BPF_TAG_SIZE];
  __u32 jited_prog_len;
  __u32 xlated_prog_len;
  __aligned_u64 jited_prog_insns;
  __aligned_u64 xlated_prog_insns;
  __u64 load_time;
  __u32 created_by_uid;
  __u32 nr_map_ids;
  __aligned_u64 map_ids;
  char name[BPF_OBJ_NAME_LEN];
  __u32 ifindex;
  __u32 gpl_compatible : 1;
  __u32 : 31;
  __u64 netns_dev;
  __u64 netns_ino;
  __u32 nr_jited_ksyms;
  __u32 nr_jited_func_lens;
  __aligned_u64 jited_ksyms;
  __aligned_u64 jited_func_lens;
  __u32 btf_id;
  __u32 func_info_rec_size;
  __aligned_u64 func_info;
  __u32 nr_func_info;
  __u32 nr_line_info;
  __aligned_u64 line_info;
  __aligned_u64 jited_line_info;
  __u32 nr_jited_line_info;
  __u32 line_info_rec_size;
  __u32 jited_line_info_rec_size;
  __u32 nr_prog_tags;
  __aligned_u64 prog_tags;
  __u64 run_time_ns;
  __u64 run_cnt;
} __attribute__((aligned(8)));
struct bpf_map_info {
  __u32 type;
  __u32 id;
  __u32 key_size;
  __u32 value_size;
  __u32 max_entries;
  __u32 map_flags;
  char name[BPF_OBJ_NAME_LEN];
  __u32 ifindex;
  __u32 btf_vmlinux_value_type_id;
  __u64 netns_dev;
  __u64 netns_ino;
  __u32 btf_id;
  __u32 btf_key_type_id;
  __u32 btf_value_type_id;
} __attribute__((aligned(8)));
struct bpf_btf_info {
  __aligned_u64 btf;
  __u32 btf_size;
  __u32 id;
} __attribute__((aligned(8)));
struct bpf_link_info {
  __u32 type;
  __u32 id;
  __u32 prog_id;
  union {
    struct {
      __aligned_u64 tp_name;
      __u32 tp_name_len;
    } raw_tracepoint;
    struct {
      __u32 attach_type;
    } tracing;
    struct {
      __u64 cgroup_id;
      __u32 attach_type;
    } cgroup;
    struct {
      __aligned_u64 target_name;
      __u32 target_name_len;
      union {
        struct {
          __u32 map_id;
        } map;
      };
    } iter;
    struct {
      __u32 netns_ino;
      __u32 attach_type;
    } netns;
    struct {
      __u32 ifindex;
    } xdp;
  };
} __attribute__((aligned(8)));
struct bpf_sock_addr {
  __u32 user_family;
  __u32 user_ip4;
  __u32 user_ip6[4];
  __u32 user_port;
  __u32 family;
  __u32 type;
  __u32 protocol;
  __u32 msg_src_ip4;
  __u32 msg_src_ip6[4];
  __bpf_md_ptr(struct bpf_sock *, sk);
};
struct bpf_sock_ops {
  __u32 op;
  union {
    __u32 args[4];
    __u32 reply;
    __u32 replylong[4];
  };
  __u32 family;
  __u32 remote_ip4;
  __u32 local_ip4;
  __u32 remote_ip6[4];
  __u32 local_ip6[4];
  __u32 remote_port;
  __u32 local_port;
  __u32 is_fullsock;
  __u32 snd_cwnd;
  __u32 srtt_us;
  __u32 bpf_sock_ops_cb_flags;
  __u32 state;
  __u32 rtt_min;
  __u32 snd_ssthresh;
  __u32 rcv_nxt;
  __u32 snd_nxt;
  __u32 snd_una;
  __u32 mss_cache;
  __u32 ecn_flags;
  __u32 rate_delivered;
  __u32 rate_interval_us;
  __u32 packets_out;
  __u32 retrans_out;
  __u32 total_retrans;
  __u32 segs_in;
  __u32 data_segs_in;
  __u32 segs_out;
  __u32 data_segs_out;
  __u32 lost_out;
  __u32 sacked_out;
  __u32 sk_txhash;
  __u64 bytes_received;
  __u64 bytes_acked;
  __bpf_md_ptr(struct bpf_sock *, sk);
  __bpf_md_ptr(void *, skb_data);
  __bpf_md_ptr(void *, skb_data_end);
  __u32 skb_len;
  __u32 skb_tcp_flags;
};
enum {
  BPF_SOCK_OPS_RTO_CB_FLAG = (1 << 0),
  BPF_SOCK_OPS_RETRANS_CB_FLAG = (1 << 1),
  BPF_SOCK_OPS_STATE_CB_FLAG = (1 << 2),
  BPF_SOCK_OPS_RTT_CB_FLAG = (1 << 3),
  BPF_SOCK_OPS_PARSE_ALL_HDR_OPT_CB_FLAG = (1 << 4),
  BPF_SOCK_OPS_PARSE_UNKNOWN_HDR_OPT_CB_FLAG = (1 << 5),
  BPF_SOCK_OPS_WRITE_HDR_OPT_CB_FLAG = (1 << 6),
  BPF_SOCK_OPS_ALL_CB_FLAGS = 0x7F,
};
enum {
  BPF_SOCK_OPS_VOID,
  BPF_SOCK_OPS_TIMEOUT_INIT,
  BPF_SOCK_OPS_RWND_INIT,
  BPF_SOCK_OPS_TCP_CONNECT_CB,
  BPF_SOCK_OPS_ACTIVE_ESTABLISHED_CB,
  BPF_SOCK_OPS_PASSIVE_ESTABLISHED_CB,
  BPF_SOCK_OPS_NEEDS_ECN,
  BPF_SOCK_OPS_BASE_RTT,
  BPF_SOCK_OPS_RTO_CB,
  BPF_SOCK_OPS_RETRANS_CB,
  BPF_SOCK_OPS_STATE_CB,
  BPF_SOCK_OPS_TCP_LISTEN_CB,
  BPF_SOCK_OPS_RTT_CB,
  BPF_SOCK_OPS_PARSE_HDR_OPT_CB,
  BPF_SOCK_OPS_HDR_OPT_LEN_CB,
  BPF_SOCK_OPS_WRITE_HDR_OPT_CB,
};
enum {
  BPF_TCP_ESTABLISHED = 1,
  BPF_TCP_SYN_SENT,
  BPF_TCP_SYN_RECV,
  BPF_TCP_FIN_WAIT1,
  BPF_TCP_FIN_WAIT2,
  BPF_TCP_TIME_WAIT,
  BPF_TCP_CLOSE,
  BPF_TCP_CLOSE_WAIT,
  BPF_TCP_LAST_ACK,
  BPF_TCP_LISTEN,
  BPF_TCP_CLOSING,
  BPF_TCP_NEW_SYN_RECV,
  BPF_TCP_MAX_STATES
};
enum {
  TCP_BPF_IW = 1001,
  TCP_BPF_SNDCWND_CLAMP = 1002,
  TCP_BPF_DELACK_MAX = 1003,
  TCP_BPF_RTO_MIN = 1004,
  TCP_BPF_SYN = 1005,
  TCP_BPF_SYN_IP = 1006,
  TCP_BPF_SYN_MAC = 1007,
};
enum {
  BPF_LOAD_HDR_OPT_TCP_SYN = (1ULL << 0),
};
enum {
  BPF_WRITE_HDR_TCP_CURRENT_MSS = 1,
  BPF_WRITE_HDR_TCP_SYNACK_COOKIE = 2,
};
struct bpf_perf_event_value {
  __u64 counter;
  __u64 enabled;
  __u64 running;
};
enum {
  BPF_DEVCG_ACC_MKNOD = (1ULL << 0),
  BPF_DEVCG_ACC_READ = (1ULL << 1),
  BPF_DEVCG_ACC_WRITE = (1ULL << 2),
};
enum {
  BPF_DEVCG_DEV_BLOCK = (1ULL << 0),
  BPF_DEVCG_DEV_CHAR = (1ULL << 1),
};
struct bpf_cgroup_dev_ctx {
  __u32 access_type;
  __u32 major;
  __u32 minor;
};
struct bpf_raw_tracepoint_args {
  __u64 args[0];
};
enum {
  BPF_FIB_LOOKUP_DIRECT = (1U << 0),
  BPF_FIB_LOOKUP_OUTPUT = (1U << 1),
};
enum {
  BPF_FIB_LKUP_RET_SUCCESS,
  BPF_FIB_LKUP_RET_BLACKHOLE,
  BPF_FIB_LKUP_RET_UNREACHABLE,
  BPF_FIB_LKUP_RET_PROHIBIT,
  BPF_FIB_LKUP_RET_NOT_FWDED,
  BPF_FIB_LKUP_RET_FWD_DISABLED,
  BPF_FIB_LKUP_RET_UNSUPP_LWT,
  BPF_FIB_LKUP_RET_NO_NEIGH,
  BPF_FIB_LKUP_RET_FRAG_NEEDED,
};
struct bpf_fib_lookup {
  __u8 family;
  __u8 l4_protocol;
  __be16 sport;
  __be16 dport;
  __u16 tot_len;
  __u32 ifindex;
  union {
    __u8 tos;
    __be32 flowinfo;
    __u32 rt_metric;
  };
  union {
    __be32 ipv4_src;
    __u32 ipv6_src[4];
  };
  union {
    __be32 ipv4_dst;
    __u32 ipv6_dst[4];
  };
  __be16 h_vlan_proto;
  __be16 h_vlan_TCI;
  __u8 smac[6];
  __u8 dmac[6];
};
struct bpf_redir_neigh {
  __u32 nh_family;
  union {
    __be32 ipv4_nh;
    __u32 ipv6_nh[4];
  };
};
enum bpf_task_fd_type {
  BPF_FD_TYPE_RAW_TRACEPOINT,
  BPF_FD_TYPE_TRACEPOINT,
  BPF_FD_TYPE_KPROBE,
  BPF_FD_TYPE_KRETPROBE,
  BPF_FD_TYPE_UPROBE,
  BPF_FD_TYPE_URETPROBE,
};
enum {
  BPF_FLOW_DISSECTOR_F_PARSE_1ST_FRAG = (1U << 0),
  BPF_FLOW_DISSECTOR_F_STOP_AT_FLOW_LABEL = (1U << 1),
  BPF_FLOW_DISSECTOR_F_STOP_AT_ENCAP = (1U << 2),
};
struct bpf_flow_keys {
  __u16 nhoff;
  __u16 thoff;
  __u16 addr_proto;
  __u8 is_frag;
  __u8 is_first_frag;
  __u8 is_encap;
  __u8 ip_proto;
  __be16 n_proto;
  __be16 sport;
  __be16 dport;
  union {
    struct {
      __be32 ipv4_src;
      __be32 ipv4_dst;
    };
    struct {
      __u32 ipv6_src[4];
      __u32 ipv6_dst[4];
    };
  };
  __u32 flags;
  __be32 flow_label;
};
struct bpf_func_info {
  __u32 insn_off;
  __u32 type_id;
};
#define BPF_LINE_INFO_LINE_NUM(line_col) ((line_col) >> 10)
#define BPF_LINE_INFO_LINE_COL(line_col) ((line_col) & 0x3ff)
struct bpf_line_info {
  __u32 insn_off;
  __u32 file_name_off;
  __u32 line_off;
  __u32 line_col;
};
struct bpf_spin_lock {
  __u32 val;
};
struct bpf_sysctl {
  __u32 write;
  __u32 file_pos;
};
struct bpf_sockopt {
  __bpf_md_ptr(struct bpf_sock *, sk);
  __bpf_md_ptr(void *, optval);
  __bpf_md_ptr(void *, optval_end);
  __s32 level;
  __s32 optname;
  __s32 optlen;
  __s32 retval;
};
struct bpf_pidns_info {
  __u32 pid;
  __u32 tgid;
};
struct bpf_sk_lookup {
  __bpf_md_ptr(struct bpf_sock *, sk);
  __u32 family;
  __u32 protocol;
  __u32 remote_ip4;
  __u32 remote_ip6[4];
  __u32 remote_port;
  __u32 local_ip4;
  __u32 local_ip6[4];
  __u32 local_port;
};
struct btf_ptr {
  void * ptr;
  __u32 type_id;
  __u32 flags;
};
enum {
  BTF_F_COMPACT = (1ULL << 0),
  BTF_F_NONAME = (1ULL << 1),
  BTF_F_PTR_RAW = (1ULL << 2),
  BTF_F_ZERO = (1ULL << 3),
};
#endif