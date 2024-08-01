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
#ifndef _UAPI_LINUX_PG_H
#define _UAPI_LINUX_PG_H
#define PG_MAGIC 'P'
#define PG_RESET 'Z'
#define PG_COMMAND 'C'
#define PG_MAX_DATA 32768
struct pg_write_hdr {
  char magic;
  char func;
  int dlen;
  int timeout;
  char packet[12];
};
struct pg_read_hdr {
  char magic;
  char scsi;
  int dlen;
  int duration;
  char pad[12];
};
#endif