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
#ifndef _UAPI_LINUX_THERMAL_H
#define _UAPI_LINUX_THERMAL_H
#define THERMAL_NAME_LENGTH 20
enum thermal_device_mode {
  THERMAL_DEVICE_DISABLED = 0,
  THERMAL_DEVICE_ENABLED,
};
enum thermal_trip_type {
  THERMAL_TRIP_ACTIVE = 0,
  THERMAL_TRIP_PASSIVE,
  THERMAL_TRIP_HOT,
  THERMAL_TRIP_CRITICAL,
};
#define THERMAL_GENL_FAMILY_NAME "thermal"
#define THERMAL_GENL_VERSION 0x01
#define THERMAL_GENL_SAMPLING_GROUP_NAME "sampling"
#define THERMAL_GENL_EVENT_GROUP_NAME "event"
enum thermal_genl_attr {
  THERMAL_GENL_ATTR_UNSPEC,
  THERMAL_GENL_ATTR_TZ,
  THERMAL_GENL_ATTR_TZ_ID,
  THERMAL_GENL_ATTR_TZ_TEMP,
  THERMAL_GENL_ATTR_TZ_TRIP,
  THERMAL_GENL_ATTR_TZ_TRIP_ID,
  THERMAL_GENL_ATTR_TZ_TRIP_TYPE,
  THERMAL_GENL_ATTR_TZ_TRIP_TEMP,
  THERMAL_GENL_ATTR_TZ_TRIP_HYST,
  THERMAL_GENL_ATTR_TZ_MODE,
  THERMAL_GENL_ATTR_TZ_NAME,
  THERMAL_GENL_ATTR_TZ_CDEV_WEIGHT,
  THERMAL_GENL_ATTR_TZ_GOV,
  THERMAL_GENL_ATTR_TZ_GOV_NAME,
  THERMAL_GENL_ATTR_CDEV,
  THERMAL_GENL_ATTR_CDEV_ID,
  THERMAL_GENL_ATTR_CDEV_CUR_STATE,
  THERMAL_GENL_ATTR_CDEV_MAX_STATE,
  THERMAL_GENL_ATTR_CDEV_NAME,
  THERMAL_GENL_ATTR_GOV_NAME,
  __THERMAL_GENL_ATTR_MAX,
};
#define THERMAL_GENL_ATTR_MAX (__THERMAL_GENL_ATTR_MAX - 1)
enum thermal_genl_sampling {
  THERMAL_GENL_SAMPLING_TEMP,
  __THERMAL_GENL_SAMPLING_MAX,
};
#define THERMAL_GENL_SAMPLING_MAX (__THERMAL_GENL_SAMPLING_MAX - 1)
enum thermal_genl_event {
  THERMAL_GENL_EVENT_UNSPEC,
  THERMAL_GENL_EVENT_TZ_CREATE,
  THERMAL_GENL_EVENT_TZ_DELETE,
  THERMAL_GENL_EVENT_TZ_DISABLE,
  THERMAL_GENL_EVENT_TZ_ENABLE,
  THERMAL_GENL_EVENT_TZ_TRIP_UP,
  THERMAL_GENL_EVENT_TZ_TRIP_DOWN,
  THERMAL_GENL_EVENT_TZ_TRIP_CHANGE,
  THERMAL_GENL_EVENT_TZ_TRIP_ADD,
  THERMAL_GENL_EVENT_TZ_TRIP_DELETE,
  THERMAL_GENL_EVENT_CDEV_ADD,
  THERMAL_GENL_EVENT_CDEV_DELETE,
  THERMAL_GENL_EVENT_CDEV_STATE_UPDATE,
  THERMAL_GENL_EVENT_TZ_GOV_CHANGE,
  __THERMAL_GENL_EVENT_MAX,
};
#define THERMAL_GENL_EVENT_MAX (__THERMAL_GENL_EVENT_MAX - 1)
enum thermal_genl_cmd {
  THERMAL_GENL_CMD_UNSPEC,
  THERMAL_GENL_CMD_TZ_GET_ID,
  THERMAL_GENL_CMD_TZ_GET_TRIP,
  THERMAL_GENL_CMD_TZ_GET_TEMP,
  THERMAL_GENL_CMD_TZ_GET_GOV,
  THERMAL_GENL_CMD_TZ_GET_MODE,
  THERMAL_GENL_CMD_CDEV_GET,
  __THERMAL_GENL_CMD_MAX,
};
#define THERMAL_GENL_CMD_MAX (__THERMAL_GENL_CMD_MAX - 1)
#endif