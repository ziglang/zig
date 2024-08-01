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
#ifndef LINUX_IO_URING_H
#define LINUX_IO_URING_H
#include <linux/fs.h>
#include <linux/types.h>
struct io_uring_sqe {
  __u8 opcode;
  __u8 flags;
  __u16 ioprio;
  __s32 fd;
  union {
    __u64 off;
    __u64 addr2;
  };
  union {
    __u64 addr;
    __u64 splice_off_in;
  };
  __u32 len;
  union {
    __kernel_rwf_t rw_flags;
    __u32 fsync_flags;
    __u16 poll_events;
    __u32 poll32_events;
    __u32 sync_range_flags;
    __u32 msg_flags;
    __u32 timeout_flags;
    __u32 accept_flags;
    __u32 cancel_flags;
    __u32 open_flags;
    __u32 statx_flags;
    __u32 fadvise_advice;
    __u32 splice_flags;
  };
  __u64 user_data;
  union {
    struct {
      union {
        __u16 buf_index;
        __u16 buf_group;
      } __attribute__((packed));
      __u16 personality;
      __s32 splice_fd_in;
    };
    __u64 __pad2[3];
  };
};
enum {
  IOSQE_FIXED_FILE_BIT,
  IOSQE_IO_DRAIN_BIT,
  IOSQE_IO_LINK_BIT,
  IOSQE_IO_HARDLINK_BIT,
  IOSQE_ASYNC_BIT,
  IOSQE_BUFFER_SELECT_BIT,
};
#define IOSQE_FIXED_FILE (1U << IOSQE_FIXED_FILE_BIT)
#define IOSQE_IO_DRAIN (1U << IOSQE_IO_DRAIN_BIT)
#define IOSQE_IO_LINK (1U << IOSQE_IO_LINK_BIT)
#define IOSQE_IO_HARDLINK (1U << IOSQE_IO_HARDLINK_BIT)
#define IOSQE_ASYNC (1U << IOSQE_ASYNC_BIT)
#define IOSQE_BUFFER_SELECT (1U << IOSQE_BUFFER_SELECT_BIT)
#define IORING_SETUP_IOPOLL (1U << 0)
#define IORING_SETUP_SQPOLL (1U << 1)
#define IORING_SETUP_SQ_AFF (1U << 2)
#define IORING_SETUP_CQSIZE (1U << 3)
#define IORING_SETUP_CLAMP (1U << 4)
#define IORING_SETUP_ATTACH_WQ (1U << 5)
#define IORING_SETUP_R_DISABLED (1U << 6)
enum {
  IORING_OP_NOP,
  IORING_OP_READV,
  IORING_OP_WRITEV,
  IORING_OP_FSYNC,
  IORING_OP_READ_FIXED,
  IORING_OP_WRITE_FIXED,
  IORING_OP_POLL_ADD,
  IORING_OP_POLL_REMOVE,
  IORING_OP_SYNC_FILE_RANGE,
  IORING_OP_SENDMSG,
  IORING_OP_RECVMSG,
  IORING_OP_TIMEOUT,
  IORING_OP_TIMEOUT_REMOVE,
  IORING_OP_ACCEPT,
  IORING_OP_ASYNC_CANCEL,
  IORING_OP_LINK_TIMEOUT,
  IORING_OP_CONNECT,
  IORING_OP_FALLOCATE,
  IORING_OP_OPENAT,
  IORING_OP_CLOSE,
  IORING_OP_FILES_UPDATE,
  IORING_OP_STATX,
  IORING_OP_READ,
  IORING_OP_WRITE,
  IORING_OP_FADVISE,
  IORING_OP_MADVISE,
  IORING_OP_SEND,
  IORING_OP_RECV,
  IORING_OP_OPENAT2,
  IORING_OP_EPOLL_CTL,
  IORING_OP_SPLICE,
  IORING_OP_PROVIDE_BUFFERS,
  IORING_OP_REMOVE_BUFFERS,
  IORING_OP_TEE,
  IORING_OP_LAST,
};
#define IORING_FSYNC_DATASYNC (1U << 0)
#define IORING_TIMEOUT_ABS (1U << 0)
#define SPLICE_F_FD_IN_FIXED (1U << 31)
struct io_uring_cqe {
  __u64 user_data;
  __s32 res;
  __u32 flags;
};
#define IORING_CQE_F_BUFFER (1U << 0)
enum {
  IORING_CQE_BUFFER_SHIFT = 16,
};
#define IORING_OFF_SQ_RING 0ULL
#define IORING_OFF_CQ_RING 0x8000000ULL
#define IORING_OFF_SQES 0x10000000ULL
struct io_sqring_offsets {
  __u32 head;
  __u32 tail;
  __u32 ring_mask;
  __u32 ring_entries;
  __u32 flags;
  __u32 dropped;
  __u32 array;
  __u32 resv1;
  __u64 resv2;
};
#define IORING_SQ_NEED_WAKEUP (1U << 0)
#define IORING_SQ_CQ_OVERFLOW (1U << 1)
struct io_cqring_offsets {
  __u32 head;
  __u32 tail;
  __u32 ring_mask;
  __u32 ring_entries;
  __u32 overflow;
  __u32 cqes;
  __u32 flags;
  __u32 resv1;
  __u64 resv2;
};
#define IORING_CQ_EVENTFD_DISABLED (1U << 0)
#define IORING_ENTER_GETEVENTS (1U << 0)
#define IORING_ENTER_SQ_WAKEUP (1U << 1)
#define IORING_ENTER_SQ_WAIT (1U << 2)
struct io_uring_params {
  __u32 sq_entries;
  __u32 cq_entries;
  __u32 flags;
  __u32 sq_thread_cpu;
  __u32 sq_thread_idle;
  __u32 features;
  __u32 wq_fd;
  __u32 resv[3];
  struct io_sqring_offsets sq_off;
  struct io_cqring_offsets cq_off;
};
#define IORING_FEAT_SINGLE_MMAP (1U << 0)
#define IORING_FEAT_NODROP (1U << 1)
#define IORING_FEAT_SUBMIT_STABLE (1U << 2)
#define IORING_FEAT_RW_CUR_POS (1U << 3)
#define IORING_FEAT_CUR_PERSONALITY (1U << 4)
#define IORING_FEAT_FAST_POLL (1U << 5)
#define IORING_FEAT_POLL_32BITS (1U << 6)
enum {
  IORING_REGISTER_BUFFERS = 0,
  IORING_UNREGISTER_BUFFERS = 1,
  IORING_REGISTER_FILES = 2,
  IORING_UNREGISTER_FILES = 3,
  IORING_REGISTER_EVENTFD = 4,
  IORING_UNREGISTER_EVENTFD = 5,
  IORING_REGISTER_FILES_UPDATE = 6,
  IORING_REGISTER_EVENTFD_ASYNC = 7,
  IORING_REGISTER_PROBE = 8,
  IORING_REGISTER_PERSONALITY = 9,
  IORING_UNREGISTER_PERSONALITY = 10,
  IORING_REGISTER_RESTRICTIONS = 11,
  IORING_REGISTER_ENABLE_RINGS = 12,
  IORING_REGISTER_LAST
};
struct io_uring_files_update {
  __u32 offset;
  __u32 resv;
  __aligned_u64 fds;
};
#define IO_URING_OP_SUPPORTED (1U << 0)
struct io_uring_probe_op {
  __u8 op;
  __u8 resv;
  __u16 flags;
  __u32 resv2;
};
struct io_uring_probe {
  __u8 last_op;
  __u8 ops_len;
  __u16 resv;
  __u32 resv2[3];
  struct io_uring_probe_op ops[0];
};
struct io_uring_restriction {
  __u16 opcode;
  union {
    __u8 register_op;
    __u8 sqe_op;
    __u8 sqe_flags;
  };
  __u8 resv;
  __u32 resv2[3];
};
enum {
  IORING_RESTRICTION_REGISTER_OP = 0,
  IORING_RESTRICTION_SQE_OP = 1,
  IORING_RESTRICTION_SQE_FLAGS_ALLOWED = 2,
  IORING_RESTRICTION_SQE_FLAGS_REQUIRED = 3,
  IORING_RESTRICTION_LAST
};
#endif