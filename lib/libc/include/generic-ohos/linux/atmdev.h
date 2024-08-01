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
#ifndef _UAPILINUX_ATMDEV_H
#define _UAPILINUX_ATMDEV_H
#include <linux/atmapi.h>
#include <linux/atm.h>
#include <linux/atmioc.h>
#define ESI_LEN 6
#define ATM_OC3_PCR (155520000 / 270 * 260 / 8 / 53)
#define ATM_25_PCR ((25600000 / 8 - 8000) / 54)
#define ATM_OC12_PCR (622080000 / 1080 * 1040 / 8 / 53)
#define ATM_DS3_PCR (8000 * 12)
#define __AAL_STAT_ITEMS __HANDLE_ITEM(tx); __HANDLE_ITEM(tx_err); __HANDLE_ITEM(rx); __HANDLE_ITEM(rx_err); __HANDLE_ITEM(rx_drop);
struct atm_aal_stats {
#define __HANDLE_ITEM(i) int i
  __AAL_STAT_ITEMS
#undef __HANDLE_ITEM
};
struct atm_dev_stats {
  struct atm_aal_stats aal0;
  struct atm_aal_stats aal34;
  struct atm_aal_stats aal5;
} __ATM_API_ALIGN;
#define ATM_GETLINKRATE _IOW('a', ATMIOC_ITF + 1, struct atmif_sioc)
#define ATM_GETNAMES _IOW('a', ATMIOC_ITF + 3, struct atm_iobuf)
#define ATM_GETTYPE _IOW('a', ATMIOC_ITF + 4, struct atmif_sioc)
#define ATM_GETESI _IOW('a', ATMIOC_ITF + 5, struct atmif_sioc)
#define ATM_GETADDR _IOW('a', ATMIOC_ITF + 6, struct atmif_sioc)
#define ATM_RSTADDR _IOW('a', ATMIOC_ITF + 7, struct atmif_sioc)
#define ATM_ADDADDR _IOW('a', ATMIOC_ITF + 8, struct atmif_sioc)
#define ATM_DELADDR _IOW('a', ATMIOC_ITF + 9, struct atmif_sioc)
#define ATM_GETCIRANGE _IOW('a', ATMIOC_ITF + 10, struct atmif_sioc)
#define ATM_SETCIRANGE _IOW('a', ATMIOC_ITF + 11, struct atmif_sioc)
#define ATM_SETESI _IOW('a', ATMIOC_ITF + 12, struct atmif_sioc)
#define ATM_SETESIF _IOW('a', ATMIOC_ITF + 13, struct atmif_sioc)
#define ATM_ADDLECSADDR _IOW('a', ATMIOC_ITF + 14, struct atmif_sioc)
#define ATM_DELLECSADDR _IOW('a', ATMIOC_ITF + 15, struct atmif_sioc)
#define ATM_GETLECSADDR _IOW('a', ATMIOC_ITF + 16, struct atmif_sioc)
#define ATM_GETSTAT _IOW('a', ATMIOC_SARCOM + 0, struct atmif_sioc)
#define ATM_GETSTATZ _IOW('a', ATMIOC_SARCOM + 1, struct atmif_sioc)
#define ATM_GETLOOP _IOW('a', ATMIOC_SARCOM + 2, struct atmif_sioc)
#define ATM_SETLOOP _IOW('a', ATMIOC_SARCOM + 3, struct atmif_sioc)
#define ATM_QUERYLOOP _IOW('a', ATMIOC_SARCOM + 4, struct atmif_sioc)
#define ATM_SETSC _IOW('a', ATMIOC_SPECIAL + 1, int)
#define ATM_SETBACKEND _IOW('a', ATMIOC_SPECIAL + 2, atm_backend_t)
#define ATM_NEWBACKENDIF _IOW('a', ATMIOC_SPECIAL + 3, atm_backend_t)
#define ATM_ADDPARTY _IOW('a', ATMIOC_SPECIAL + 4, struct atm_iobuf)
#define ATM_DROPPARTY _IOW('a', ATMIOC_SPECIAL + 5, int)
#define ATM_BACKEND_RAW 0
#define ATM_BACKEND_PPP 1
#define ATM_BACKEND_BR2684 2
#define ATM_ITFTYP_LEN 8
#define __ATM_LM_NONE 0
#define __ATM_LM_AAL 1
#define __ATM_LM_ATM 2
#define __ATM_LM_PHY 8
#define __ATM_LM_ANALOG 16
#define __ATM_LM_MKLOC(n) ((n))
#define __ATM_LM_MKRMT(n) ((n) << 8)
#define __ATM_LM_XTLOC(n) ((n) & 0xff)
#define __ATM_LM_XTRMT(n) (((n) >> 8) & 0xff)
#define ATM_LM_NONE 0
#define ATM_LM_LOC_AAL __ATM_LM_MKLOC(__ATM_LM_AAL)
#define ATM_LM_LOC_ATM __ATM_LM_MKLOC(__ATM_LM_ATM)
#define ATM_LM_LOC_PHY __ATM_LM_MKLOC(__ATM_LM_PHY)
#define ATM_LM_LOC_ANALOG __ATM_LM_MKLOC(__ATM_LM_ANALOG)
#define ATM_LM_RMT_AAL __ATM_LM_MKRMT(__ATM_LM_AAL)
#define ATM_LM_RMT_ATM __ATM_LM_MKRMT(__ATM_LM_ATM)
#define ATM_LM_RMT_PHY __ATM_LM_MKRMT(__ATM_LM_PHY)
#define ATM_LM_RMT_ANALOG __ATM_LM_MKRMT(__ATM_LM_ANALOG)
struct atm_iobuf {
  int length;
  void __user * buffer;
};
#define ATM_CI_MAX - 1
struct atm_cirange {
  signed char vpi_bits;
  signed char vci_bits;
};
#define ATM_SC_RX 1024
#define ATM_SC_TX 2048
#define ATM_BACKLOG_DEFAULT 32
#define ATM_MF_IMMED 1
#define ATM_MF_INC_RSV 2
#define ATM_MF_INC_SHP 4
#define ATM_MF_DEC_RSV 8
#define ATM_MF_DEC_SHP 16
#define ATM_MF_BWD 32
#define ATM_MF_SET (ATM_MF_INC_RSV | ATM_MF_INC_SHP | ATM_MF_DEC_RSV | ATM_MF_DEC_SHP | ATM_MF_BWD)
#define ATM_VS_IDLE 0
#define ATM_VS_CONNECTED 1
#define ATM_VS_CLOSING 2
#define ATM_VS_LISTEN 3
#define ATM_VS_INUSE 4
#define ATM_VS_BOUND 5
#define ATM_VS2TXT_MAP "IDLE", "CONNECTED", "CLOSING", "LISTEN", "INUSE", "BOUND"
#define ATM_VF2TXT_MAP "ADDR", "READY", "PARTIAL", "REGIS", "RELEASED", "HASQOS", "LISTEN", "META", "256", "512", "1024", "2048", "SESSION", "HASSAP", "BOUND", "CLOSE"
#endif