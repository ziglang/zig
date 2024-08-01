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
#ifndef _UAPI_UVESAFB_H
#define _UAPI_UVESAFB_H
#include <linux/types.h>
struct v86_regs {
  __u32 ebx;
  __u32 ecx;
  __u32 edx;
  __u32 esi;
  __u32 edi;
  __u32 ebp;
  __u32 eax;
  __u32 eip;
  __u32 eflags;
  __u32 esp;
  __u16 cs;
  __u16 ss;
  __u16 es;
  __u16 ds;
  __u16 fs;
  __u16 gs;
};
#define TF_VBEIB 0x01
#define TF_BUF_ESDI 0x02
#define TF_BUF_ESBX 0x04
#define TF_BUF_RET 0x08
#define TF_EXIT 0x10
struct uvesafb_task {
  __u8 flags;
  int buf_len;
  struct v86_regs regs;
};
#define VBE_CAP_CAN_SWITCH_DAC 0x01
#define VBE_CAP_VGACOMPAT 0x02
struct vbe_ib {
  char vbe_signature[4];
  __u16 vbe_version;
  __u32 oem_string_ptr;
  __u32 capabilities;
  __u32 mode_list_ptr;
  __u16 total_memory;
  __u16 oem_software_rev;
  __u32 oem_vendor_name_ptr;
  __u32 oem_product_name_ptr;
  __u32 oem_product_rev_ptr;
  __u8 reserved[222];
  char oem_data[256];
  char misc_data[512];
} __attribute__((packed));
#endif