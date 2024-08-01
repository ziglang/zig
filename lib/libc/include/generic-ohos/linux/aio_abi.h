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
#ifndef __LINUX__AIO_ABI_H
#define __LINUX__AIO_ABI_H
#include <linux/types.h>
#include <linux/fs.h>
#include <asm/byteorder.h>
typedef __kernel_ulong_t aio_context_t;
enum {
  IOCB_CMD_PREAD = 0,
  IOCB_CMD_PWRITE = 1,
  IOCB_CMD_FSYNC = 2,
  IOCB_CMD_FDSYNC = 3,
  IOCB_CMD_POLL = 5,
  IOCB_CMD_NOOP = 6,
  IOCB_CMD_PREADV = 7,
  IOCB_CMD_PWRITEV = 8,
};
#define IOCB_FLAG_RESFD (1 << 0)
#define IOCB_FLAG_IOPRIO (1 << 1)
struct io_event {
  __u64 data;
  __u64 obj;
  __s64 res;
  __s64 res2;
};
struct iocb {
  __u64 aio_data;
#if defined(__BYTE_ORDER) ? __BYTE_ORDER == __LITTLE_ENDIAN : defined(__LITTLE_ENDIAN)
  __u32 aio_key;
  __kernel_rwf_t aio_rw_flags;
#elif defined(__BYTE_ORDER)?__BYTE_ORDER==__BIG_ENDIAN:defined(__BIG_ENDIAN)
  __kernel_rwf_t aio_rw_flags;
  __u32 aio_key;
#else
#error edit for your odd byteorder .
#endif
  __u16 aio_lio_opcode;
  __s16 aio_reqprio;
  __u32 aio_fildes;
  __u64 aio_buf;
  __u64 aio_nbytes;
  __s64 aio_offset;
  __u64 aio_reserved2;
  __u32 aio_flags;
  __u32 aio_resfd;
};
#undef IFBIG
#undef IFLITTLE
#endif