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
#ifndef __UHID_H_
#define __UHID_H_
#include <linux/input.h>
#include <linux/types.h>
#include <linux/hid.h>
enum uhid_event_type {
  __UHID_LEGACY_CREATE,
  UHID_DESTROY,
  UHID_START,
  UHID_STOP,
  UHID_OPEN,
  UHID_CLOSE,
  UHID_OUTPUT,
  __UHID_LEGACY_OUTPUT_EV,
  __UHID_LEGACY_INPUT,
  UHID_GET_REPORT,
  UHID_GET_REPORT_REPLY,
  UHID_CREATE2,
  UHID_INPUT2,
  UHID_SET_REPORT,
  UHID_SET_REPORT_REPLY,
};
struct uhid_create2_req {
  __u8 name[128];
  __u8 phys[64];
  __u8 uniq[64];
  __u16 rd_size;
  __u16 bus;
  __u32 vendor;
  __u32 product;
  __u32 version;
  __u32 country;
  __u8 rd_data[HID_MAX_DESCRIPTOR_SIZE];
} __attribute__((__packed__));
enum uhid_dev_flag {
  UHID_DEV_NUMBERED_FEATURE_REPORTS = (1ULL << 0),
  UHID_DEV_NUMBERED_OUTPUT_REPORTS = (1ULL << 1),
  UHID_DEV_NUMBERED_INPUT_REPORTS = (1ULL << 2),
};
struct uhid_start_req {
  __u64 dev_flags;
};
#define UHID_DATA_MAX 4096
enum uhid_report_type {
  UHID_FEATURE_REPORT,
  UHID_OUTPUT_REPORT,
  UHID_INPUT_REPORT,
};
struct uhid_input2_req {
  __u16 size;
  __u8 data[UHID_DATA_MAX];
} __attribute__((__packed__));
struct uhid_output_req {
  __u8 data[UHID_DATA_MAX];
  __u16 size;
  __u8 rtype;
} __attribute__((__packed__));
struct uhid_get_report_req {
  __u32 id;
  __u8 rnum;
  __u8 rtype;
} __attribute__((__packed__));
struct uhid_get_report_reply_req {
  __u32 id;
  __u16 err;
  __u16 size;
  __u8 data[UHID_DATA_MAX];
} __attribute__((__packed__));
struct uhid_set_report_req {
  __u32 id;
  __u8 rnum;
  __u8 rtype;
  __u16 size;
  __u8 data[UHID_DATA_MAX];
} __attribute__((__packed__));
struct uhid_set_report_reply_req {
  __u32 id;
  __u16 err;
} __attribute__((__packed__));
enum uhid_legacy_event_type {
  UHID_CREATE = __UHID_LEGACY_CREATE,
  UHID_OUTPUT_EV = __UHID_LEGACY_OUTPUT_EV,
  UHID_INPUT = __UHID_LEGACY_INPUT,
  UHID_FEATURE = UHID_GET_REPORT,
  UHID_FEATURE_ANSWER = UHID_GET_REPORT_REPLY,
};
struct uhid_create_req {
  __u8 name[128];
  __u8 phys[64];
  __u8 uniq[64];
  __u8 __user * rd_data;
  __u16 rd_size;
  __u16 bus;
  __u32 vendor;
  __u32 product;
  __u32 version;
  __u32 country;
} __attribute__((__packed__));
struct uhid_input_req {
  __u8 data[UHID_DATA_MAX];
  __u16 size;
} __attribute__((__packed__));
struct uhid_output_ev_req {
  __u16 type;
  __u16 code;
  __s32 value;
} __attribute__((__packed__));
struct uhid_feature_req {
  __u32 id;
  __u8 rnum;
  __u8 rtype;
} __attribute__((__packed__));
struct uhid_feature_answer_req {
  __u32 id;
  __u16 err;
  __u16 size;
  __u8 data[UHID_DATA_MAX];
} __attribute__((__packed__));
struct uhid_event {
  __u32 type;
  union {
    struct uhid_create_req create;
    struct uhid_input_req input;
    struct uhid_output_req output;
    struct uhid_output_ev_req output_ev;
    struct uhid_feature_req feature;
    struct uhid_get_report_req get_report;
    struct uhid_feature_answer_req feature_answer;
    struct uhid_get_report_reply_req get_report_reply;
    struct uhid_create2_req create2;
    struct uhid_input2_req input2;
    struct uhid_set_report_req set_report;
    struct uhid_set_report_reply_req set_report_reply;
    struct uhid_start_req start;
  } u;
} __attribute__((__packed__));
#endif