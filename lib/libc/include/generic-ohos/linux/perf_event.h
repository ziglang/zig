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
#ifndef _UAPI_LINUX_PERF_EVENT_H
#define _UAPI_LINUX_PERF_EVENT_H
#include <linux/types.h>
#include <linux/ioctl.h>
#include <asm/byteorder.h>
enum perf_type_id {
  PERF_TYPE_HARDWARE = 0,
  PERF_TYPE_SOFTWARE = 1,
  PERF_TYPE_TRACEPOINT = 2,
  PERF_TYPE_HW_CACHE = 3,
  PERF_TYPE_RAW = 4,
  PERF_TYPE_BREAKPOINT = 5,
  PERF_TYPE_MAX,
};
enum perf_hw_id {
  PERF_COUNT_HW_CPU_CYCLES = 0,
  PERF_COUNT_HW_INSTRUCTIONS = 1,
  PERF_COUNT_HW_CACHE_REFERENCES = 2,
  PERF_COUNT_HW_CACHE_MISSES = 3,
  PERF_COUNT_HW_BRANCH_INSTRUCTIONS = 4,
  PERF_COUNT_HW_BRANCH_MISSES = 5,
  PERF_COUNT_HW_BUS_CYCLES = 6,
  PERF_COUNT_HW_STALLED_CYCLES_FRONTEND = 7,
  PERF_COUNT_HW_STALLED_CYCLES_BACKEND = 8,
  PERF_COUNT_HW_REF_CPU_CYCLES = 9,
  PERF_COUNT_HW_MAX,
};
enum perf_hw_cache_id {
  PERF_COUNT_HW_CACHE_L1D = 0,
  PERF_COUNT_HW_CACHE_L1I = 1,
  PERF_COUNT_HW_CACHE_LL = 2,
  PERF_COUNT_HW_CACHE_DTLB = 3,
  PERF_COUNT_HW_CACHE_ITLB = 4,
  PERF_COUNT_HW_CACHE_BPU = 5,
  PERF_COUNT_HW_CACHE_NODE = 6,
  PERF_COUNT_HW_CACHE_MAX,
};
enum perf_hw_cache_op_id {
  PERF_COUNT_HW_CACHE_OP_READ = 0,
  PERF_COUNT_HW_CACHE_OP_WRITE = 1,
  PERF_COUNT_HW_CACHE_OP_PREFETCH = 2,
  PERF_COUNT_HW_CACHE_OP_MAX,
};
enum perf_hw_cache_op_result_id {
  PERF_COUNT_HW_CACHE_RESULT_ACCESS = 0,
  PERF_COUNT_HW_CACHE_RESULT_MISS = 1,
  PERF_COUNT_HW_CACHE_RESULT_MAX,
};
enum perf_sw_ids {
  PERF_COUNT_SW_CPU_CLOCK = 0,
  PERF_COUNT_SW_TASK_CLOCK = 1,
  PERF_COUNT_SW_PAGE_FAULTS = 2,
  PERF_COUNT_SW_CONTEXT_SWITCHES = 3,
  PERF_COUNT_SW_CPU_MIGRATIONS = 4,
  PERF_COUNT_SW_PAGE_FAULTS_MIN = 5,
  PERF_COUNT_SW_PAGE_FAULTS_MAJ = 6,
  PERF_COUNT_SW_ALIGNMENT_FAULTS = 7,
  PERF_COUNT_SW_EMULATION_FAULTS = 8,
  PERF_COUNT_SW_DUMMY = 9,
  PERF_COUNT_SW_BPF_OUTPUT = 10,
  PERF_COUNT_SW_MAX,
};
enum perf_event_sample_format {
  PERF_SAMPLE_IP = 1U << 0,
  PERF_SAMPLE_TID = 1U << 1,
  PERF_SAMPLE_TIME = 1U << 2,
  PERF_SAMPLE_ADDR = 1U << 3,
  PERF_SAMPLE_READ = 1U << 4,
  PERF_SAMPLE_CALLCHAIN = 1U << 5,
  PERF_SAMPLE_ID = 1U << 6,
  PERF_SAMPLE_CPU = 1U << 7,
  PERF_SAMPLE_PERIOD = 1U << 8,
  PERF_SAMPLE_STREAM_ID = 1U << 9,
  PERF_SAMPLE_RAW = 1U << 10,
  PERF_SAMPLE_BRANCH_STACK = 1U << 11,
  PERF_SAMPLE_REGS_USER = 1U << 12,
  PERF_SAMPLE_STACK_USER = 1U << 13,
  PERF_SAMPLE_WEIGHT = 1U << 14,
  PERF_SAMPLE_DATA_SRC = 1U << 15,
  PERF_SAMPLE_IDENTIFIER = 1U << 16,
  PERF_SAMPLE_TRANSACTION = 1U << 17,
  PERF_SAMPLE_REGS_INTR = 1U << 18,
  PERF_SAMPLE_PHYS_ADDR = 1U << 19,
  PERF_SAMPLE_AUX = 1U << 20,
  PERF_SAMPLE_CGROUP = 1U << 21,
  PERF_SAMPLE_MAX = 1U << 22,
  __PERF_SAMPLE_CALLCHAIN_EARLY = 1ULL << 63,
};
enum perf_branch_sample_type_shift {
  PERF_SAMPLE_BRANCH_USER_SHIFT = 0,
  PERF_SAMPLE_BRANCH_KERNEL_SHIFT = 1,
  PERF_SAMPLE_BRANCH_HV_SHIFT = 2,
  PERF_SAMPLE_BRANCH_ANY_SHIFT = 3,
  PERF_SAMPLE_BRANCH_ANY_CALL_SHIFT = 4,
  PERF_SAMPLE_BRANCH_ANY_RETURN_SHIFT = 5,
  PERF_SAMPLE_BRANCH_IND_CALL_SHIFT = 6,
  PERF_SAMPLE_BRANCH_ABORT_TX_SHIFT = 7,
  PERF_SAMPLE_BRANCH_IN_TX_SHIFT = 8,
  PERF_SAMPLE_BRANCH_NO_TX_SHIFT = 9,
  PERF_SAMPLE_BRANCH_COND_SHIFT = 10,
  PERF_SAMPLE_BRANCH_CALL_STACK_SHIFT = 11,
  PERF_SAMPLE_BRANCH_IND_JUMP_SHIFT = 12,
  PERF_SAMPLE_BRANCH_CALL_SHIFT = 13,
  PERF_SAMPLE_BRANCH_NO_FLAGS_SHIFT = 14,
  PERF_SAMPLE_BRANCH_NO_CYCLES_SHIFT = 15,
  PERF_SAMPLE_BRANCH_TYPE_SAVE_SHIFT = 16,
  PERF_SAMPLE_BRANCH_HW_INDEX_SHIFT = 17,
  PERF_SAMPLE_BRANCH_MAX_SHIFT
};
enum perf_branch_sample_type {
  PERF_SAMPLE_BRANCH_USER = 1U << PERF_SAMPLE_BRANCH_USER_SHIFT,
  PERF_SAMPLE_BRANCH_KERNEL = 1U << PERF_SAMPLE_BRANCH_KERNEL_SHIFT,
  PERF_SAMPLE_BRANCH_HV = 1U << PERF_SAMPLE_BRANCH_HV_SHIFT,
  PERF_SAMPLE_BRANCH_ANY = 1U << PERF_SAMPLE_BRANCH_ANY_SHIFT,
  PERF_SAMPLE_BRANCH_ANY_CALL = 1U << PERF_SAMPLE_BRANCH_ANY_CALL_SHIFT,
  PERF_SAMPLE_BRANCH_ANY_RETURN = 1U << PERF_SAMPLE_BRANCH_ANY_RETURN_SHIFT,
  PERF_SAMPLE_BRANCH_IND_CALL = 1U << PERF_SAMPLE_BRANCH_IND_CALL_SHIFT,
  PERF_SAMPLE_BRANCH_ABORT_TX = 1U << PERF_SAMPLE_BRANCH_ABORT_TX_SHIFT,
  PERF_SAMPLE_BRANCH_IN_TX = 1U << PERF_SAMPLE_BRANCH_IN_TX_SHIFT,
  PERF_SAMPLE_BRANCH_NO_TX = 1U << PERF_SAMPLE_BRANCH_NO_TX_SHIFT,
  PERF_SAMPLE_BRANCH_COND = 1U << PERF_SAMPLE_BRANCH_COND_SHIFT,
  PERF_SAMPLE_BRANCH_CALL_STACK = 1U << PERF_SAMPLE_BRANCH_CALL_STACK_SHIFT,
  PERF_SAMPLE_BRANCH_IND_JUMP = 1U << PERF_SAMPLE_BRANCH_IND_JUMP_SHIFT,
  PERF_SAMPLE_BRANCH_CALL = 1U << PERF_SAMPLE_BRANCH_CALL_SHIFT,
  PERF_SAMPLE_BRANCH_NO_FLAGS = 1U << PERF_SAMPLE_BRANCH_NO_FLAGS_SHIFT,
  PERF_SAMPLE_BRANCH_NO_CYCLES = 1U << PERF_SAMPLE_BRANCH_NO_CYCLES_SHIFT,
  PERF_SAMPLE_BRANCH_TYPE_SAVE = 1U << PERF_SAMPLE_BRANCH_TYPE_SAVE_SHIFT,
  PERF_SAMPLE_BRANCH_HW_INDEX = 1U << PERF_SAMPLE_BRANCH_HW_INDEX_SHIFT,
  PERF_SAMPLE_BRANCH_MAX = 1U << PERF_SAMPLE_BRANCH_MAX_SHIFT,
};
enum {
  PERF_BR_UNKNOWN = 0,
  PERF_BR_COND = 1,
  PERF_BR_UNCOND = 2,
  PERF_BR_IND = 3,
  PERF_BR_CALL = 4,
  PERF_BR_IND_CALL = 5,
  PERF_BR_RET = 6,
  PERF_BR_SYSCALL = 7,
  PERF_BR_SYSRET = 8,
  PERF_BR_COND_CALL = 9,
  PERF_BR_COND_RET = 10,
  PERF_BR_MAX,
};
#define PERF_SAMPLE_BRANCH_PLM_ALL (PERF_SAMPLE_BRANCH_USER | PERF_SAMPLE_BRANCH_KERNEL | PERF_SAMPLE_BRANCH_HV)
enum perf_sample_regs_abi {
  PERF_SAMPLE_REGS_ABI_NONE = 0,
  PERF_SAMPLE_REGS_ABI_32 = 1,
  PERF_SAMPLE_REGS_ABI_64 = 2,
};
enum {
  PERF_TXN_ELISION = (1 << 0),
  PERF_TXN_TRANSACTION = (1 << 1),
  PERF_TXN_SYNC = (1 << 2),
  PERF_TXN_ASYNC = (1 << 3),
  PERF_TXN_RETRY = (1 << 4),
  PERF_TXN_CONFLICT = (1 << 5),
  PERF_TXN_CAPACITY_WRITE = (1 << 6),
  PERF_TXN_CAPACITY_READ = (1 << 7),
  PERF_TXN_MAX = (1 << 8),
  PERF_TXN_ABORT_MASK = (0xffffffffULL << 32),
  PERF_TXN_ABORT_SHIFT = 32,
};
enum perf_event_read_format {
  PERF_FORMAT_TOTAL_TIME_ENABLED = 1U << 0,
  PERF_FORMAT_TOTAL_TIME_RUNNING = 1U << 1,
  PERF_FORMAT_ID = 1U << 2,
  PERF_FORMAT_GROUP = 1U << 3,
  PERF_FORMAT_MAX = 1U << 4,
};
#define PERF_ATTR_SIZE_VER0 64
#define PERF_ATTR_SIZE_VER1 72
#define PERF_ATTR_SIZE_VER2 80
#define PERF_ATTR_SIZE_VER3 96
#define PERF_ATTR_SIZE_VER4 104
#define PERF_ATTR_SIZE_VER5 112
#define PERF_ATTR_SIZE_VER6 120
struct perf_event_attr {
  __u32 type;
  __u32 size;
  __u64 config;
  union {
    __u64 sample_period;
    __u64 sample_freq;
  };
  __u64 sample_type;
  __u64 read_format;
  __u64 disabled : 1, inherit : 1, pinned : 1, exclusive : 1, exclude_user : 1, exclude_kernel : 1, exclude_hv : 1, exclude_idle : 1, mmap : 1, comm : 1, freq : 1, inherit_stat : 1, enable_on_exec : 1, task : 1, watermark : 1, precise_ip : 2, mmap_data : 1, sample_id_all : 1, exclude_host : 1, exclude_guest : 1, exclude_callchain_kernel : 1, exclude_callchain_user : 1, mmap2 : 1, comm_exec : 1, use_clockid : 1, context_switch : 1, write_backward : 1, namespaces : 1, ksymbol : 1, bpf_event : 1, aux_output : 1, cgroup : 1, text_poke : 1, __reserved_1 : 30;
  union {
    __u32 wakeup_events;
    __u32 wakeup_watermark;
  };
  __u32 bp_type;
  union {
    __u64 bp_addr;
    __u64 kprobe_func;
    __u64 uprobe_path;
    __u64 config1;
  };
  union {
    __u64 bp_len;
    __u64 kprobe_addr;
    __u64 probe_offset;
    __u64 config2;
  };
  __u64 branch_sample_type;
  __u64 sample_regs_user;
  __u32 sample_stack_user;
  __s32 clockid;
  __u64 sample_regs_intr;
  __u32 aux_watermark;
  __u16 sample_max_stack;
  __u16 __reserved_2;
  __u32 aux_sample_size;
  __u32 __reserved_3;
};
struct perf_event_query_bpf {
  __u32 ids_len;
  __u32 prog_cnt;
  __u32 ids[0];
};
#define PERF_EVENT_IOC_ENABLE _IO('$', 0)
#define PERF_EVENT_IOC_DISABLE _IO('$', 1)
#define PERF_EVENT_IOC_REFRESH _IO('$', 2)
#define PERF_EVENT_IOC_RESET _IO('$', 3)
#define PERF_EVENT_IOC_PERIOD _IOW('$', 4, __u64)
#define PERF_EVENT_IOC_SET_OUTPUT _IO('$', 5)
#define PERF_EVENT_IOC_SET_FILTER _IOW('$', 6, char *)
#define PERF_EVENT_IOC_ID _IOR('$', 7, __u64 *)
#define PERF_EVENT_IOC_SET_BPF _IOW('$', 8, __u32)
#define PERF_EVENT_IOC_PAUSE_OUTPUT _IOW('$', 9, __u32)
#define PERF_EVENT_IOC_QUERY_BPF _IOWR('$', 10, struct perf_event_query_bpf *)
#define PERF_EVENT_IOC_MODIFY_ATTRIBUTES _IOW('$', 11, struct perf_event_attr *)
enum perf_event_ioc_flags {
  PERF_IOC_FLAG_GROUP = 1U << 0,
};
struct perf_event_mmap_page {
  __u32 version;
  __u32 compat_version;
  __u32 lock;
  __u32 index;
  __s64 offset;
  __u64 time_enabled;
  __u64 time_running;
  union {
    __u64 capabilities;
    struct {
      __u64 cap_bit0 : 1, cap_bit0_is_deprecated : 1, cap_user_rdpmc : 1, cap_user_time : 1, cap_user_time_zero : 1, cap_user_time_short : 1, cap_____res : 58;
    };
  };
  __u16 pmc_width;
  __u16 time_shift;
  __u32 time_mult;
  __u64 time_offset;
  __u64 time_zero;
  __u32 size;
  __u32 __reserved_1;
  __u64 time_cycles;
  __u64 time_mask;
  __u8 __reserved[116 * 8];
  __u64 data_head;
  __u64 data_tail;
  __u64 data_offset;
  __u64 data_size;
  __u64 aux_head;
  __u64 aux_tail;
  __u64 aux_offset;
  __u64 aux_size;
};
#define PERF_RECORD_MISC_CPUMODE_MASK (7 << 0)
#define PERF_RECORD_MISC_CPUMODE_UNKNOWN (0 << 0)
#define PERF_RECORD_MISC_KERNEL (1 << 0)
#define PERF_RECORD_MISC_USER (2 << 0)
#define PERF_RECORD_MISC_HYPERVISOR (3 << 0)
#define PERF_RECORD_MISC_GUEST_KERNEL (4 << 0)
#define PERF_RECORD_MISC_GUEST_USER (5 << 0)
#define PERF_RECORD_MISC_PROC_MAP_PARSE_TIMEOUT (1 << 12)
#define PERF_RECORD_MISC_MMAP_DATA (1 << 13)
#define PERF_RECORD_MISC_COMM_EXEC (1 << 13)
#define PERF_RECORD_MISC_FORK_EXEC (1 << 13)
#define PERF_RECORD_MISC_SWITCH_OUT (1 << 13)
#define PERF_RECORD_MISC_EXACT_IP (1 << 14)
#define PERF_RECORD_MISC_SWITCH_OUT_PREEMPT (1 << 14)
#define PERF_RECORD_MISC_EXT_RESERVED (1 << 15)
struct perf_event_header {
  __u32 type;
  __u16 misc;
  __u16 size;
};
struct perf_ns_link_info {
  __u64 dev;
  __u64 ino;
};
enum {
  NET_NS_INDEX = 0,
  UTS_NS_INDEX = 1,
  IPC_NS_INDEX = 2,
  PID_NS_INDEX = 3,
  USER_NS_INDEX = 4,
  MNT_NS_INDEX = 5,
  CGROUP_NS_INDEX = 6,
  NR_NAMESPACES,
};
enum perf_event_type {
  PERF_RECORD_MMAP = 1,
  PERF_RECORD_LOST = 2,
  PERF_RECORD_COMM = 3,
  PERF_RECORD_EXIT = 4,
  PERF_RECORD_THROTTLE = 5,
  PERF_RECORD_UNTHROTTLE = 6,
  PERF_RECORD_FORK = 7,
  PERF_RECORD_READ = 8,
  PERF_RECORD_SAMPLE = 9,
  PERF_RECORD_MMAP2 = 10,
  PERF_RECORD_AUX = 11,
  PERF_RECORD_ITRACE_START = 12,
  PERF_RECORD_LOST_SAMPLES = 13,
  PERF_RECORD_SWITCH = 14,
  PERF_RECORD_SWITCH_CPU_WIDE = 15,
  PERF_RECORD_NAMESPACES = 16,
  PERF_RECORD_KSYMBOL = 17,
  PERF_RECORD_BPF_EVENT = 18,
  PERF_RECORD_CGROUP = 19,
  PERF_RECORD_TEXT_POKE = 20,
  PERF_RECORD_MAX,
};
enum perf_record_ksymbol_type {
  PERF_RECORD_KSYMBOL_TYPE_UNKNOWN = 0,
  PERF_RECORD_KSYMBOL_TYPE_BPF = 1,
  PERF_RECORD_KSYMBOL_TYPE_OOL = 2,
  PERF_RECORD_KSYMBOL_TYPE_MAX
};
#define PERF_RECORD_KSYMBOL_FLAGS_UNREGISTER (1 << 0)
enum perf_bpf_event_type {
  PERF_BPF_EVENT_UNKNOWN = 0,
  PERF_BPF_EVENT_PROG_LOAD = 1,
  PERF_BPF_EVENT_PROG_UNLOAD = 2,
  PERF_BPF_EVENT_MAX,
};
#define PERF_MAX_STACK_DEPTH 127
#define PERF_MAX_CONTEXTS_PER_STACK 8
enum perf_callchain_context {
  PERF_CONTEXT_HV = (__u64) - 32,
  PERF_CONTEXT_KERNEL = (__u64) - 128,
  PERF_CONTEXT_USER = (__u64) - 512,
  PERF_CONTEXT_GUEST = (__u64) - 2048,
  PERF_CONTEXT_GUEST_KERNEL = (__u64) - 2176,
  PERF_CONTEXT_GUEST_USER = (__u64) - 2560,
  PERF_CONTEXT_MAX = (__u64) - 4095,
};
#define PERF_AUX_FLAG_TRUNCATED 0x01
#define PERF_AUX_FLAG_OVERWRITE 0x02
#define PERF_AUX_FLAG_PARTIAL 0x04
#define PERF_AUX_FLAG_COLLISION 0x08
#define PERF_FLAG_FD_NO_GROUP (1UL << 0)
#define PERF_FLAG_FD_OUTPUT (1UL << 1)
#define PERF_FLAG_PID_CGROUP (1UL << 2)
#define PERF_FLAG_FD_CLOEXEC (1UL << 3)
#ifdef __LITTLE_ENDIAN_BITFIELD
union perf_mem_data_src {
  __u64 val;
  struct {
    __u64 mem_op : 5, mem_lvl : 14, mem_snoop : 5, mem_lock : 2, mem_dtlb : 7, mem_lvl_num : 4, mem_remote : 1, mem_snoopx : 2, mem_rsvd : 24;
  };
};
#elif defined(__BIG_ENDIAN_BITFIELD)
union perf_mem_data_src {
  __u64 val;
  struct {
    __u64 mem_rsvd : 24, mem_snoopx : 2, mem_remote : 1, mem_lvl_num : 4, mem_dtlb : 7, mem_lock : 2, mem_snoop : 5, mem_lvl : 14, mem_op : 5;
  };
};
#else
#error "Unknown endianness"
#endif
#define PERF_MEM_OP_NA 0x01
#define PERF_MEM_OP_LOAD 0x02
#define PERF_MEM_OP_STORE 0x04
#define PERF_MEM_OP_PFETCH 0x08
#define PERF_MEM_OP_EXEC 0x10
#define PERF_MEM_OP_SHIFT 0
#define PERF_MEM_LVL_NA 0x01
#define PERF_MEM_LVL_HIT 0x02
#define PERF_MEM_LVL_MISS 0x04
#define PERF_MEM_LVL_L1 0x08
#define PERF_MEM_LVL_LFB 0x10
#define PERF_MEM_LVL_L2 0x20
#define PERF_MEM_LVL_L3 0x40
#define PERF_MEM_LVL_LOC_RAM 0x80
#define PERF_MEM_LVL_REM_RAM1 0x100
#define PERF_MEM_LVL_REM_RAM2 0x200
#define PERF_MEM_LVL_REM_CCE1 0x400
#define PERF_MEM_LVL_REM_CCE2 0x800
#define PERF_MEM_LVL_IO 0x1000
#define PERF_MEM_LVL_UNC 0x2000
#define PERF_MEM_LVL_SHIFT 5
#define PERF_MEM_REMOTE_REMOTE 0x01
#define PERF_MEM_REMOTE_SHIFT 37
#define PERF_MEM_LVLNUM_L1 0x01
#define PERF_MEM_LVLNUM_L2 0x02
#define PERF_MEM_LVLNUM_L3 0x03
#define PERF_MEM_LVLNUM_L4 0x04
#define PERF_MEM_LVLNUM_ANY_CACHE 0x0b
#define PERF_MEM_LVLNUM_LFB 0x0c
#define PERF_MEM_LVLNUM_RAM 0x0d
#define PERF_MEM_LVLNUM_PMEM 0x0e
#define PERF_MEM_LVLNUM_NA 0x0f
#define PERF_MEM_LVLNUM_SHIFT 33
#define PERF_MEM_SNOOP_NA 0x01
#define PERF_MEM_SNOOP_NONE 0x02
#define PERF_MEM_SNOOP_HIT 0x04
#define PERF_MEM_SNOOP_MISS 0x08
#define PERF_MEM_SNOOP_HITM 0x10
#define PERF_MEM_SNOOP_SHIFT 19
#define PERF_MEM_SNOOPX_FWD 0x01
#define PERF_MEM_SNOOPX_SHIFT 38
#define PERF_MEM_LOCK_NA 0x01
#define PERF_MEM_LOCK_LOCKED 0x02
#define PERF_MEM_LOCK_SHIFT 24
#define PERF_MEM_TLB_NA 0x01
#define PERF_MEM_TLB_HIT 0x02
#define PERF_MEM_TLB_MISS 0x04
#define PERF_MEM_TLB_L1 0x08
#define PERF_MEM_TLB_L2 0x10
#define PERF_MEM_TLB_WK 0x20
#define PERF_MEM_TLB_OS 0x40
#define PERF_MEM_TLB_SHIFT 26
#define PERF_MEM_S(a,s) (((__u64) PERF_MEM_ ##a ##_ ##s) << PERF_MEM_ ##a ##_SHIFT)
struct perf_branch_entry {
  __u64 from;
  __u64 to;
  __u64 mispred : 1, predicted : 1, in_tx : 1, abort : 1, cycles : 16, type : 4, reserved : 40;
};
#endif