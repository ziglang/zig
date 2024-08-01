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
#ifndef _UAPI_GPIO_H_
#define _UAPI_GPIO_H_
#include <linux/const.h>
#include <linux/ioctl.h>
#include <linux/types.h>
#define GPIO_MAX_NAME_SIZE 32
struct gpiochip_info {
  char name[GPIO_MAX_NAME_SIZE];
  char label[GPIO_MAX_NAME_SIZE];
  __u32 lines;
};
#define GPIO_V2_LINES_MAX 64
#define GPIO_V2_LINE_NUM_ATTRS_MAX 10
enum gpio_v2_line_flag {
  GPIO_V2_LINE_FLAG_USED = _BITULL(0),
  GPIO_V2_LINE_FLAG_ACTIVE_LOW = _BITULL(1),
  GPIO_V2_LINE_FLAG_INPUT = _BITULL(2),
  GPIO_V2_LINE_FLAG_OUTPUT = _BITULL(3),
  GPIO_V2_LINE_FLAG_EDGE_RISING = _BITULL(4),
  GPIO_V2_LINE_FLAG_EDGE_FALLING = _BITULL(5),
  GPIO_V2_LINE_FLAG_OPEN_DRAIN = _BITULL(6),
  GPIO_V2_LINE_FLAG_OPEN_SOURCE = _BITULL(7),
  GPIO_V2_LINE_FLAG_BIAS_PULL_UP = _BITULL(8),
  GPIO_V2_LINE_FLAG_BIAS_PULL_DOWN = _BITULL(9),
  GPIO_V2_LINE_FLAG_BIAS_DISABLED = _BITULL(10),
};
struct gpio_v2_line_values {
  __aligned_u64 bits;
  __aligned_u64 mask;
};
enum gpio_v2_line_attr_id {
  GPIO_V2_LINE_ATTR_ID_FLAGS = 1,
  GPIO_V2_LINE_ATTR_ID_OUTPUT_VALUES = 2,
  GPIO_V2_LINE_ATTR_ID_DEBOUNCE = 3,
};
struct gpio_v2_line_attribute {
  __u32 id;
  __u32 padding;
  union {
    __aligned_u64 flags;
    __aligned_u64 values;
    __u32 debounce_period_us;
  };
};
struct gpio_v2_line_config_attribute {
  struct gpio_v2_line_attribute attr;
  __aligned_u64 mask;
};
struct gpio_v2_line_config {
  __aligned_u64 flags;
  __u32 num_attrs;
  __u32 padding[5];
  struct gpio_v2_line_config_attribute attrs[GPIO_V2_LINE_NUM_ATTRS_MAX];
};
struct gpio_v2_line_request {
  __u32 offsets[GPIO_V2_LINES_MAX];
  char consumer[GPIO_MAX_NAME_SIZE];
  struct gpio_v2_line_config config;
  __u32 num_lines;
  __u32 event_buffer_size;
  __u32 padding[5];
  __s32 fd;
};
struct gpio_v2_line_info {
  char name[GPIO_MAX_NAME_SIZE];
  char consumer[GPIO_MAX_NAME_SIZE];
  __u32 offset;
  __u32 num_attrs;
  __aligned_u64 flags;
  struct gpio_v2_line_attribute attrs[GPIO_V2_LINE_NUM_ATTRS_MAX];
  __u32 padding[4];
};
enum gpio_v2_line_changed_type {
  GPIO_V2_LINE_CHANGED_REQUESTED = 1,
  GPIO_V2_LINE_CHANGED_RELEASED = 2,
  GPIO_V2_LINE_CHANGED_CONFIG = 3,
};
struct gpio_v2_line_info_changed {
  struct gpio_v2_line_info info;
  __aligned_u64 timestamp_ns;
  __u32 event_type;
  __u32 padding[5];
};
enum gpio_v2_line_event_id {
  GPIO_V2_LINE_EVENT_RISING_EDGE = 1,
  GPIO_V2_LINE_EVENT_FALLING_EDGE = 2,
};
struct gpio_v2_line_event {
  __aligned_u64 timestamp_ns;
  __u32 id;
  __u32 offset;
  __u32 seqno;
  __u32 line_seqno;
  __u32 padding[6];
};
#define GPIOLINE_FLAG_KERNEL (1UL << 0)
#define GPIOLINE_FLAG_IS_OUT (1UL << 1)
#define GPIOLINE_FLAG_ACTIVE_LOW (1UL << 2)
#define GPIOLINE_FLAG_OPEN_DRAIN (1UL << 3)
#define GPIOLINE_FLAG_OPEN_SOURCE (1UL << 4)
#define GPIOLINE_FLAG_BIAS_PULL_UP (1UL << 5)
#define GPIOLINE_FLAG_BIAS_PULL_DOWN (1UL << 6)
#define GPIOLINE_FLAG_BIAS_DISABLE (1UL << 7)
struct gpioline_info {
  __u32 line_offset;
  __u32 flags;
  char name[GPIO_MAX_NAME_SIZE];
  char consumer[GPIO_MAX_NAME_SIZE];
};
#define GPIOHANDLES_MAX 64
enum {
  GPIOLINE_CHANGED_REQUESTED = 1,
  GPIOLINE_CHANGED_RELEASED,
  GPIOLINE_CHANGED_CONFIG,
};
struct gpioline_info_changed {
  struct gpioline_info info;
  __u64 timestamp;
  __u32 event_type;
  __u32 padding[5];
};
#define GPIOHANDLE_REQUEST_INPUT (1UL << 0)
#define GPIOHANDLE_REQUEST_OUTPUT (1UL << 1)
#define GPIOHANDLE_REQUEST_ACTIVE_LOW (1UL << 2)
#define GPIOHANDLE_REQUEST_OPEN_DRAIN (1UL << 3)
#define GPIOHANDLE_REQUEST_OPEN_SOURCE (1UL << 4)
#define GPIOHANDLE_REQUEST_BIAS_PULL_UP (1UL << 5)
#define GPIOHANDLE_REQUEST_BIAS_PULL_DOWN (1UL << 6)
#define GPIOHANDLE_REQUEST_BIAS_DISABLE (1UL << 7)
struct gpiohandle_request {
  __u32 lineoffsets[GPIOHANDLES_MAX];
  __u32 flags;
  __u8 default_values[GPIOHANDLES_MAX];
  char consumer_label[GPIO_MAX_NAME_SIZE];
  __u32 lines;
  int fd;
};
struct gpiohandle_config {
  __u32 flags;
  __u8 default_values[GPIOHANDLES_MAX];
  __u32 padding[4];
};
struct gpiohandle_data {
  __u8 values[GPIOHANDLES_MAX];
};
#define GPIOEVENT_REQUEST_RISING_EDGE (1UL << 0)
#define GPIOEVENT_REQUEST_FALLING_EDGE (1UL << 1)
#define GPIOEVENT_REQUEST_BOTH_EDGES ((1UL << 0) | (1UL << 1))
struct gpioevent_request {
  __u32 lineoffset;
  __u32 handleflags;
  __u32 eventflags;
  char consumer_label[GPIO_MAX_NAME_SIZE];
  int fd;
};
#define GPIOEVENT_EVENT_RISING_EDGE 0x01
#define GPIOEVENT_EVENT_FALLING_EDGE 0x02
struct gpioevent_data {
  __u64 timestamp;
  __u32 id;
};
#define GPIO_GET_CHIPINFO_IOCTL _IOR(0xB4, 0x01, struct gpiochip_info)
#define GPIO_GET_LINEINFO_UNWATCH_IOCTL _IOWR(0xB4, 0x0C, __u32)
#define GPIO_V2_GET_LINEINFO_IOCTL _IOWR(0xB4, 0x05, struct gpio_v2_line_info)
#define GPIO_V2_GET_LINEINFO_WATCH_IOCTL _IOWR(0xB4, 0x06, struct gpio_v2_line_info)
#define GPIO_V2_GET_LINE_IOCTL _IOWR(0xB4, 0x07, struct gpio_v2_line_request)
#define GPIO_V2_LINE_SET_CONFIG_IOCTL _IOWR(0xB4, 0x0D, struct gpio_v2_line_config)
#define GPIO_V2_LINE_GET_VALUES_IOCTL _IOWR(0xB4, 0x0E, struct gpio_v2_line_values)
#define GPIO_V2_LINE_SET_VALUES_IOCTL _IOWR(0xB4, 0x0F, struct gpio_v2_line_values)
#define GPIO_GET_LINEINFO_IOCTL _IOWR(0xB4, 0x02, struct gpioline_info)
#define GPIO_GET_LINEHANDLE_IOCTL _IOWR(0xB4, 0x03, struct gpiohandle_request)
#define GPIO_GET_LINEEVENT_IOCTL _IOWR(0xB4, 0x04, struct gpioevent_request)
#define GPIOHANDLE_GET_LINE_VALUES_IOCTL _IOWR(0xB4, 0x08, struct gpiohandle_data)
#define GPIOHANDLE_SET_LINE_VALUES_IOCTL _IOWR(0xB4, 0x09, struct gpiohandle_data)
#define GPIOHANDLE_SET_CONFIG_IOCTL _IOWR(0xB4, 0x0A, struct gpiohandle_config)
#define GPIO_GET_LINEINFO_WATCH_IOCTL _IOWR(0xB4, 0x0B, struct gpioline_info)
#endif