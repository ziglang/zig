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
#ifndef __UAPI_VBOX_VMMDEV_TYPES_H__
#define __UAPI_VBOX_VMMDEV_TYPES_H__
#include <asm/bitsperlong.h>
#include <linux/types.h>
#define VMMDEV_ASSERT_SIZE(type,size) typedef char type ##_asrt_size[1 - 2 * ! ! (sizeof(struct type) != (size))]
enum vmmdev_request_type {
  VMMDEVREQ_INVALID_REQUEST = 0,
  VMMDEVREQ_GET_MOUSE_STATUS = 1,
  VMMDEVREQ_SET_MOUSE_STATUS = 2,
  VMMDEVREQ_SET_POINTER_SHAPE = 3,
  VMMDEVREQ_GET_HOST_VERSION = 4,
  VMMDEVREQ_IDLE = 5,
  VMMDEVREQ_GET_HOST_TIME = 10,
  VMMDEVREQ_GET_HYPERVISOR_INFO = 20,
  VMMDEVREQ_SET_HYPERVISOR_INFO = 21,
  VMMDEVREQ_REGISTER_PATCH_MEMORY = 22,
  VMMDEVREQ_DEREGISTER_PATCH_MEMORY = 23,
  VMMDEVREQ_SET_POWER_STATUS = 30,
  VMMDEVREQ_ACKNOWLEDGE_EVENTS = 41,
  VMMDEVREQ_CTL_GUEST_FILTER_MASK = 42,
  VMMDEVREQ_REPORT_GUEST_INFO = 50,
  VMMDEVREQ_REPORT_GUEST_INFO2 = 58,
  VMMDEVREQ_REPORT_GUEST_STATUS = 59,
  VMMDEVREQ_REPORT_GUEST_USER_STATE = 74,
  VMMDEVREQ_GET_DISPLAY_CHANGE_REQ = 51,
  VMMDEVREQ_VIDEMODE_SUPPORTED = 52,
  VMMDEVREQ_GET_HEIGHT_REDUCTION = 53,
  VMMDEVREQ_GET_DISPLAY_CHANGE_REQ2 = 54,
  VMMDEVREQ_REPORT_GUEST_CAPABILITIES = 55,
  VMMDEVREQ_SET_GUEST_CAPABILITIES = 56,
  VMMDEVREQ_VIDEMODE_SUPPORTED2 = 57,
  VMMDEVREQ_GET_DISPLAY_CHANGE_REQEX = 80,
  VMMDEVREQ_GET_DISPLAY_CHANGE_REQ_MULTI = 81,
  VMMDEVREQ_HGCM_CONNECT = 60,
  VMMDEVREQ_HGCM_DISCONNECT = 61,
  VMMDEVREQ_HGCM_CALL32 = 62,
  VMMDEVREQ_HGCM_CALL64 = 63,
  VMMDEVREQ_HGCM_CANCEL = 64,
  VMMDEVREQ_HGCM_CANCEL2 = 65,
  VMMDEVREQ_VIDEO_ACCEL_ENABLE = 70,
  VMMDEVREQ_VIDEO_ACCEL_FLUSH = 71,
  VMMDEVREQ_VIDEO_SET_VISIBLE_REGION = 72,
  VMMDEVREQ_GET_SEAMLESS_CHANGE_REQ = 73,
  VMMDEVREQ_QUERY_CREDENTIALS = 100,
  VMMDEVREQ_REPORT_CREDENTIALS_JUDGEMENT = 101,
  VMMDEVREQ_REPORT_GUEST_STATS = 110,
  VMMDEVREQ_GET_MEMBALLOON_CHANGE_REQ = 111,
  VMMDEVREQ_GET_STATISTICS_CHANGE_REQ = 112,
  VMMDEVREQ_CHANGE_MEMBALLOON = 113,
  VMMDEVREQ_GET_VRDPCHANGE_REQ = 150,
  VMMDEVREQ_LOG_STRING = 200,
  VMMDEVREQ_GET_CPU_HOTPLUG_REQ = 210,
  VMMDEVREQ_SET_CPU_HOTPLUG_STATUS = 211,
  VMMDEVREQ_REGISTER_SHARED_MODULE = 212,
  VMMDEVREQ_UNREGISTER_SHARED_MODULE = 213,
  VMMDEVREQ_CHECK_SHARED_MODULES = 214,
  VMMDEVREQ_GET_PAGE_SHARING_STATUS = 215,
  VMMDEVREQ_DEBUG_IS_PAGE_SHARED = 216,
  VMMDEVREQ_GET_SESSION_ID = 217,
  VMMDEVREQ_WRITE_COREDUMP = 218,
  VMMDEVREQ_GUEST_HEARTBEAT = 219,
  VMMDEVREQ_HEARTBEAT_CONFIGURE = 220,
  VMMDEVREQ_NT_BUG_CHECK = 221,
  VMMDEVREQ_VIDEO_UPDATE_MONITOR_POSITIONS = 222,
  VMMDEVREQ_SIZEHACK = 0x7fffffff
};
#if __BITS_PER_LONG == 64
#define VMMDEVREQ_HGCM_CALL VMMDEVREQ_HGCM_CALL64
#else
#define VMMDEVREQ_HGCM_CALL VMMDEVREQ_HGCM_CALL32
#endif
#define VMMDEV_REQUESTOR_USR_NOT_GIVEN 0x00000000
#define VMMDEV_REQUESTOR_USR_DRV 0x00000001
#define VMMDEV_REQUESTOR_USR_DRV_OTHER 0x00000002
#define VMMDEV_REQUESTOR_USR_ROOT 0x00000003
#define VMMDEV_REQUESTOR_USR_USER 0x00000006
#define VMMDEV_REQUESTOR_USR_MASK 0x00000007
#define VMMDEV_REQUESTOR_KERNEL 0x00000000
#define VMMDEV_REQUESTOR_USERMODE 0x00000008
#define VMMDEV_REQUESTOR_MODE_MASK 0x00000008
#define VMMDEV_REQUESTOR_CON_DONT_KNOW 0x00000000
#define VMMDEV_REQUESTOR_CON_NO 0x00000010
#define VMMDEV_REQUESTOR_CON_YES 0x00000020
#define VMMDEV_REQUESTOR_CON_MASK 0x00000030
#define VMMDEV_REQUESTOR_GRP_VBOX 0x00000080
#define VMMDEV_REQUESTOR_TRUST_NOT_GIVEN 0x00000000
#define VMMDEV_REQUESTOR_TRUST_UNTRUSTED 0x00001000
#define VMMDEV_REQUESTOR_TRUST_LOW 0x00002000
#define VMMDEV_REQUESTOR_TRUST_MEDIUM 0x00003000
#define VMMDEV_REQUESTOR_TRUST_MEDIUM_PLUS 0x00004000
#define VMMDEV_REQUESTOR_TRUST_HIGH 0x00005000
#define VMMDEV_REQUESTOR_TRUST_SYSTEM 0x00006000
#define VMMDEV_REQUESTOR_TRUST_PROTECTED 0x00007000
#define VMMDEV_REQUESTOR_TRUST_MASK 0x00007000
#define VMMDEV_REQUESTOR_USER_DEVICE 0x00008000
enum vmmdev_hgcm_service_location_type {
  VMMDEV_HGCM_LOC_INVALID = 0,
  VMMDEV_HGCM_LOC_LOCALHOST = 1,
  VMMDEV_HGCM_LOC_LOCALHOST_EXISTING = 2,
  VMMDEV_HGCM_LOC_SIZEHACK = 0x7fffffff
};
struct vmmdev_hgcm_service_location_localhost {
  char service_name[128];
};
struct vmmdev_hgcm_service_location {
  enum vmmdev_hgcm_service_location_type type;
  union {
    struct vmmdev_hgcm_service_location_localhost localhost;
  } u;
};
enum vmmdev_hgcm_function_parameter_type {
  VMMDEV_HGCM_PARM_TYPE_INVALID = 0,
  VMMDEV_HGCM_PARM_TYPE_32BIT = 1,
  VMMDEV_HGCM_PARM_TYPE_64BIT = 2,
  VMMDEV_HGCM_PARM_TYPE_PHYSADDR = 3,
  VMMDEV_HGCM_PARM_TYPE_LINADDR = 4,
  VMMDEV_HGCM_PARM_TYPE_LINADDR_IN = 5,
  VMMDEV_HGCM_PARM_TYPE_LINADDR_OUT = 6,
  VMMDEV_HGCM_PARM_TYPE_LINADDR_KERNEL = 7,
  VMMDEV_HGCM_PARM_TYPE_LINADDR_KERNEL_IN = 8,
  VMMDEV_HGCM_PARM_TYPE_LINADDR_KERNEL_OUT = 9,
  VMMDEV_HGCM_PARM_TYPE_PAGELIST = 10,
  VMMDEV_HGCM_PARM_TYPE_SIZEHACK = 0x7fffffff
};
struct vmmdev_hgcm_function_parameter32 {
  enum vmmdev_hgcm_function_parameter_type type;
  union {
    __u32 value32;
    __u64 value64;
    struct {
      __u32 size;
      union {
        __u32 phys_addr;
        __u32 linear_addr;
      } u;
    } pointer;
    struct {
      __u32 size;
      __u32 offset;
    } page_list;
  } u;
} __packed;
struct vmmdev_hgcm_function_parameter64 {
  enum vmmdev_hgcm_function_parameter_type type;
  union {
    __u32 value32;
    __u64 value64;
    struct {
      __u32 size;
      union {
        __u64 phys_addr;
        __u64 linear_addr;
      } u;
    } __packed pointer;
    struct {
      __u32 size;
      __u32 offset;
    } page_list;
  } __packed u;
} __packed;
#if __BITS_PER_LONG == 64
#define vmmdev_hgcm_function_parameter vmmdev_hgcm_function_parameter64
#else
#define vmmdev_hgcm_function_parameter vmmdev_hgcm_function_parameter32
#endif
#define VMMDEV_HGCM_F_PARM_DIRECTION_NONE 0x00000000U
#define VMMDEV_HGCM_F_PARM_DIRECTION_TO_HOST 0x00000001U
#define VMMDEV_HGCM_F_PARM_DIRECTION_FROM_HOST 0x00000002U
#define VMMDEV_HGCM_F_PARM_DIRECTION_BOTH 0x00000003U
struct vmmdev_hgcm_pagelist {
  __u32 flags;
  __u16 offset_first_page;
  __u16 page_count;
  __u64 pages[1];
};
#endif