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
#ifndef __ISST_IF_H
#define __ISST_IF_H
#include <linux/types.h>
struct isst_if_platform_info {
  __u16 api_version;
  __u16 driver_version;
  __u16 max_cmds_per_ioctl;
  __u8 mbox_supported;
  __u8 mmio_supported;
};
struct isst_if_cpu_map {
  __u32 logical_cpu;
  __u32 physical_cpu;
};
struct isst_if_cpu_maps {
  __u32 cmd_count;
  struct isst_if_cpu_map cpu_map[1];
};
struct isst_if_io_reg {
  __u32 read_write;
  __u32 logical_cpu;
  __u32 reg;
  __u32 value;
};
struct isst_if_io_regs {
  __u32 req_count;
  struct isst_if_io_reg io_reg[1];
};
struct isst_if_mbox_cmd {
  __u32 logical_cpu;
  __u32 parameter;
  __u32 req_data;
  __u32 resp_data;
  __u16 command;
  __u16 sub_command;
  __u32 reserved;
};
struct isst_if_mbox_cmds {
  __u32 cmd_count;
  struct isst_if_mbox_cmd mbox_cmd[1];
};
struct isst_if_msr_cmd {
  __u32 read_write;
  __u32 logical_cpu;
  __u64 msr;
  __u64 data;
};
struct isst_if_msr_cmds {
  __u32 cmd_count;
  struct isst_if_msr_cmd msr_cmd[1];
};
#define ISST_IF_MAGIC 0xFE
#define ISST_IF_GET_PLATFORM_INFO _IOR(ISST_IF_MAGIC, 0, struct isst_if_platform_info *)
#define ISST_IF_GET_PHY_ID _IOWR(ISST_IF_MAGIC, 1, struct isst_if_cpu_map *)
#define ISST_IF_IO_CMD _IOW(ISST_IF_MAGIC, 2, struct isst_if_io_regs *)
#define ISST_IF_MBOX_COMMAND _IOWR(ISST_IF_MAGIC, 3, struct isst_if_mbox_cmds *)
#define ISST_IF_MSR_COMMAND _IOWR(ISST_IF_MAGIC, 4, struct isst_if_msr_cmds *)
#endif