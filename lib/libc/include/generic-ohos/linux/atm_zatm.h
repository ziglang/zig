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
#ifndef LINUX_ATM_ZATM_H
#define LINUX_ATM_ZATM_H
#include <linux/atmapi.h>
#include <linux/atmioc.h>
#define ZATM_GETPOOL _IOW('a', ATMIOC_SARPRV + 1, struct atmif_sioc)
#define ZATM_GETPOOLZ _IOW('a', ATMIOC_SARPRV + 2, struct atmif_sioc)
#define ZATM_SETPOOL _IOW('a', ATMIOC_SARPRV + 3, struct atmif_sioc)
struct zatm_pool_info {
  int ref_count;
  int low_water, high_water;
  int rqa_count, rqu_count;
  int offset, next_off;
  int next_cnt, next_thres;
};
struct zatm_pool_req {
  int pool_num;
  struct zatm_pool_info info;
};
#define ZATM_OAM_POOL 0
#define ZATM_AAL0_POOL 1
#define ZATM_AAL5_POOL_BASE 2
#define ZATM_LAST_POOL ZATM_AAL5_POOL_BASE + 10
#define ZATM_TIMER_HISTORY_SIZE 16
#endif