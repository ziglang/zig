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
#ifndef _LINUX_FIREWIRE_CDEV_H
#define _LINUX_FIREWIRE_CDEV_H
#include <linux/ioctl.h>
#include <linux/types.h>
#include <linux/firewire-constants.h>
#define FW_CDEV_EVENT_BUS_RESET 0x00
#define FW_CDEV_EVENT_RESPONSE 0x01
#define FW_CDEV_EVENT_REQUEST 0x02
#define FW_CDEV_EVENT_ISO_INTERRUPT 0x03
#define FW_CDEV_EVENT_ISO_RESOURCE_ALLOCATED 0x04
#define FW_CDEV_EVENT_ISO_RESOURCE_DEALLOCATED 0x05
#define FW_CDEV_EVENT_REQUEST2 0x06
#define FW_CDEV_EVENT_PHY_PACKET_SENT 0x07
#define FW_CDEV_EVENT_PHY_PACKET_RECEIVED 0x08
#define FW_CDEV_EVENT_ISO_INTERRUPT_MULTICHANNEL 0x09
struct fw_cdev_event_common {
  __u64 closure;
  __u32 type;
};
struct fw_cdev_event_bus_reset {
  __u64 closure;
  __u32 type;
  __u32 node_id;
  __u32 local_node_id;
  __u32 bm_node_id;
  __u32 irm_node_id;
  __u32 root_node_id;
  __u32 generation;
};
struct fw_cdev_event_response {
  __u64 closure;
  __u32 type;
  __u32 rcode;
  __u32 length;
  __u32 data[0];
};
struct fw_cdev_event_request {
  __u64 closure;
  __u32 type;
  __u32 tcode;
  __u64 offset;
  __u32 handle;
  __u32 length;
  __u32 data[0];
};
struct fw_cdev_event_request2 {
  __u64 closure;
  __u32 type;
  __u32 tcode;
  __u64 offset;
  __u32 source_node_id;
  __u32 destination_node_id;
  __u32 card;
  __u32 generation;
  __u32 handle;
  __u32 length;
  __u32 data[0];
};
struct fw_cdev_event_iso_interrupt {
  __u64 closure;
  __u32 type;
  __u32 cycle;
  __u32 header_length;
  __u32 header[0];
};
struct fw_cdev_event_iso_interrupt_mc {
  __u64 closure;
  __u32 type;
  __u32 completed;
};
struct fw_cdev_event_iso_resource {
  __u64 closure;
  __u32 type;
  __u32 handle;
  __s32 channel;
  __s32 bandwidth;
};
struct fw_cdev_event_phy_packet {
  __u64 closure;
  __u32 type;
  __u32 rcode;
  __u32 length;
  __u32 data[0];
};
union fw_cdev_event {
  struct fw_cdev_event_common common;
  struct fw_cdev_event_bus_reset bus_reset;
  struct fw_cdev_event_response response;
  struct fw_cdev_event_request request;
  struct fw_cdev_event_request2 request2;
  struct fw_cdev_event_iso_interrupt iso_interrupt;
  struct fw_cdev_event_iso_interrupt_mc iso_interrupt_mc;
  struct fw_cdev_event_iso_resource iso_resource;
  struct fw_cdev_event_phy_packet phy_packet;
};
#define FW_CDEV_IOC_GET_INFO _IOWR('#', 0x00, struct fw_cdev_get_info)
#define FW_CDEV_IOC_SEND_REQUEST _IOW('#', 0x01, struct fw_cdev_send_request)
#define FW_CDEV_IOC_ALLOCATE _IOWR('#', 0x02, struct fw_cdev_allocate)
#define FW_CDEV_IOC_DEALLOCATE _IOW('#', 0x03, struct fw_cdev_deallocate)
#define FW_CDEV_IOC_SEND_RESPONSE _IOW('#', 0x04, struct fw_cdev_send_response)
#define FW_CDEV_IOC_INITIATE_BUS_RESET _IOW('#', 0x05, struct fw_cdev_initiate_bus_reset)
#define FW_CDEV_IOC_ADD_DESCRIPTOR _IOWR('#', 0x06, struct fw_cdev_add_descriptor)
#define FW_CDEV_IOC_REMOVE_DESCRIPTOR _IOW('#', 0x07, struct fw_cdev_remove_descriptor)
#define FW_CDEV_IOC_CREATE_ISO_CONTEXT _IOWR('#', 0x08, struct fw_cdev_create_iso_context)
#define FW_CDEV_IOC_QUEUE_ISO _IOWR('#', 0x09, struct fw_cdev_queue_iso)
#define FW_CDEV_IOC_START_ISO _IOW('#', 0x0a, struct fw_cdev_start_iso)
#define FW_CDEV_IOC_STOP_ISO _IOW('#', 0x0b, struct fw_cdev_stop_iso)
#define FW_CDEV_IOC_GET_CYCLE_TIMER _IOR('#', 0x0c, struct fw_cdev_get_cycle_timer)
#define FW_CDEV_IOC_ALLOCATE_ISO_RESOURCE _IOWR('#', 0x0d, struct fw_cdev_allocate_iso_resource)
#define FW_CDEV_IOC_DEALLOCATE_ISO_RESOURCE _IOW('#', 0x0e, struct fw_cdev_deallocate)
#define FW_CDEV_IOC_ALLOCATE_ISO_RESOURCE_ONCE _IOW('#', 0x0f, struct fw_cdev_allocate_iso_resource)
#define FW_CDEV_IOC_DEALLOCATE_ISO_RESOURCE_ONCE _IOW('#', 0x10, struct fw_cdev_allocate_iso_resource)
#define FW_CDEV_IOC_GET_SPEED _IO('#', 0x11)
#define FW_CDEV_IOC_SEND_BROADCAST_REQUEST _IOW('#', 0x12, struct fw_cdev_send_request)
#define FW_CDEV_IOC_SEND_STREAM_PACKET _IOW('#', 0x13, struct fw_cdev_send_stream_packet)
#define FW_CDEV_IOC_GET_CYCLE_TIMER2 _IOWR('#', 0x14, struct fw_cdev_get_cycle_timer2)
#define FW_CDEV_IOC_SEND_PHY_PACKET _IOWR('#', 0x15, struct fw_cdev_send_phy_packet)
#define FW_CDEV_IOC_RECEIVE_PHY_PACKETS _IOW('#', 0x16, struct fw_cdev_receive_phy_packets)
#define FW_CDEV_IOC_SET_ISO_CHANNELS _IOW('#', 0x17, struct fw_cdev_set_iso_channels)
#define FW_CDEV_IOC_FLUSH_ISO _IOW('#', 0x18, struct fw_cdev_flush_iso)
struct fw_cdev_get_info {
  __u32 version;
  __u32 rom_length;
  __u64 rom;
  __u64 bus_reset;
  __u64 bus_reset_closure;
  __u32 card;
};
struct fw_cdev_send_request {
  __u32 tcode;
  __u32 length;
  __u64 offset;
  __u64 closure;
  __u64 data;
  __u32 generation;
};
struct fw_cdev_send_response {
  __u32 rcode;
  __u32 length;
  __u64 data;
  __u32 handle;
};
struct fw_cdev_allocate {
  __u64 offset;
  __u64 closure;
  __u32 length;
  __u32 handle;
  __u64 region_end;
};
struct fw_cdev_deallocate {
  __u32 handle;
};
#define FW_CDEV_LONG_RESET 0
#define FW_CDEV_SHORT_RESET 1
struct fw_cdev_initiate_bus_reset {
  __u32 type;
};
struct fw_cdev_add_descriptor {
  __u32 immediate;
  __u32 key;
  __u64 data;
  __u32 length;
  __u32 handle;
};
struct fw_cdev_remove_descriptor {
  __u32 handle;
};
#define FW_CDEV_ISO_CONTEXT_TRANSMIT 0
#define FW_CDEV_ISO_CONTEXT_RECEIVE 1
#define FW_CDEV_ISO_CONTEXT_RECEIVE_MULTICHANNEL 2
struct fw_cdev_create_iso_context {
  __u32 type;
  __u32 header_size;
  __u32 channel;
  __u32 speed;
  __u64 closure;
  __u32 handle;
};
struct fw_cdev_set_iso_channels {
  __u64 channels;
  __u32 handle;
};
#define FW_CDEV_ISO_PAYLOAD_LENGTH(v) (v)
#define FW_CDEV_ISO_INTERRUPT (1 << 16)
#define FW_CDEV_ISO_SKIP (1 << 17)
#define FW_CDEV_ISO_SYNC (1 << 17)
#define FW_CDEV_ISO_TAG(v) ((v) << 18)
#define FW_CDEV_ISO_SY(v) ((v) << 20)
#define FW_CDEV_ISO_HEADER_LENGTH(v) ((v) << 24)
struct fw_cdev_iso_packet {
  __u32 control;
  __u32 header[0];
};
struct fw_cdev_queue_iso {
  __u64 packets;
  __u64 data;
  __u32 size;
  __u32 handle;
};
#define FW_CDEV_ISO_CONTEXT_MATCH_TAG0 1
#define FW_CDEV_ISO_CONTEXT_MATCH_TAG1 2
#define FW_CDEV_ISO_CONTEXT_MATCH_TAG2 4
#define FW_CDEV_ISO_CONTEXT_MATCH_TAG3 8
#define FW_CDEV_ISO_CONTEXT_MATCH_ALL_TAGS 15
struct fw_cdev_start_iso {
  __s32 cycle;
  __u32 sync;
  __u32 tags;
  __u32 handle;
};
struct fw_cdev_stop_iso {
  __u32 handle;
};
struct fw_cdev_flush_iso {
  __u32 handle;
};
struct fw_cdev_get_cycle_timer {
  __u64 local_time;
  __u32 cycle_timer;
};
struct fw_cdev_get_cycle_timer2 {
  __s64 tv_sec;
  __s32 tv_nsec;
  __s32 clk_id;
  __u32 cycle_timer;
};
struct fw_cdev_allocate_iso_resource {
  __u64 closure;
  __u64 channels;
  __u32 bandwidth;
  __u32 handle;
};
struct fw_cdev_send_stream_packet {
  __u32 length;
  __u32 tag;
  __u32 channel;
  __u32 sy;
  __u64 closure;
  __u64 data;
  __u32 generation;
  __u32 speed;
};
struct fw_cdev_send_phy_packet {
  __u64 closure;
  __u32 data[2];
  __u32 generation;
};
struct fw_cdev_receive_phy_packets {
  __u64 closure;
};
#define FW_CDEV_VERSION 3
#endif