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
#ifndef _LINUX_ATMBR2684_H
#define _LINUX_ATMBR2684_H
#include <linux/types.h>
#include <linux/atm.h>
#include <linux/if.h>
#define BR2684_MEDIA_ETHERNET (0)
#define BR2684_MEDIA_802_4 (1)
#define BR2684_MEDIA_TR (2)
#define BR2684_MEDIA_FDDI (3)
#define BR2684_MEDIA_802_6 (4)
#define BR2684_FLAG_ROUTED (1 << 16)
#define BR2684_FCSIN_NO (0)
#define BR2684_FCSIN_IGNORE (1)
#define BR2684_FCSIN_VERIFY (2)
#define BR2684_FCSOUT_NO (0)
#define BR2684_FCSOUT_SENDZERO (1)
#define BR2684_FCSOUT_GENERATE (2)
#define BR2684_ENCAPS_VC (0)
#define BR2684_ENCAPS_LLC (1)
#define BR2684_ENCAPS_AUTODETECT (2)
#define BR2684_PAYLOAD_ROUTED (0)
#define BR2684_PAYLOAD_BRIDGED (1)
struct atm_newif_br2684 {
  atm_backend_t backend_num;
  int media;
  char ifname[IFNAMSIZ];
  int mtu;
};
#define BR2684_FIND_BYNOTHING (0)
#define BR2684_FIND_BYNUM (1)
#define BR2684_FIND_BYIFNAME (2)
struct br2684_if_spec {
  int method;
  union {
    char ifname[IFNAMSIZ];
    int devnum;
  } spec;
};
struct atm_backend_br2684 {
  atm_backend_t backend_num;
  struct br2684_if_spec ifspec;
  int fcs_in;
  int fcs_out;
  int fcs_auto;
  int encaps;
  int has_vpiid;
  __u8 vpn_id[7];
  int send_padding;
  int min_size;
};
struct br2684_filter {
  __be32 prefix;
  __be32 netmask;
};
struct br2684_filter_set {
  struct br2684_if_spec ifspec;
  struct br2684_filter filter;
};
enum br2684_payload {
  p_routed = BR2684_PAYLOAD_ROUTED,
  p_bridged = BR2684_PAYLOAD_BRIDGED,
};
#define BR2684_SETFILT _IOW('a', ATMIOC_BACKEND + 0, struct br2684_filter_set)
#endif