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
#ifndef _LINUX_VHOST_H
#define _LINUX_VHOST_H
#include <linux/vhost_types.h>
#include <linux/types.h>
#include <linux/ioctl.h>
#define VHOST_FILE_UNBIND - 1
#define VHOST_VIRTIO 0xAF
#define VHOST_GET_FEATURES _IOR(VHOST_VIRTIO, 0x00, __u64)
#define VHOST_SET_FEATURES _IOW(VHOST_VIRTIO, 0x00, __u64)
#define VHOST_SET_OWNER _IO(VHOST_VIRTIO, 0x01)
#define VHOST_RESET_OWNER _IO(VHOST_VIRTIO, 0x02)
#define VHOST_SET_MEM_TABLE _IOW(VHOST_VIRTIO, 0x03, struct vhost_memory)
#define VHOST_SET_LOG_BASE _IOW(VHOST_VIRTIO, 0x04, __u64)
#define VHOST_SET_LOG_FD _IOW(VHOST_VIRTIO, 0x07, int)
#define VHOST_SET_VRING_NUM _IOW(VHOST_VIRTIO, 0x10, struct vhost_vring_state)
#define VHOST_SET_VRING_ADDR _IOW(VHOST_VIRTIO, 0x11, struct vhost_vring_addr)
#define VHOST_SET_VRING_BASE _IOW(VHOST_VIRTIO, 0x12, struct vhost_vring_state)
#define VHOST_GET_VRING_BASE _IOWR(VHOST_VIRTIO, 0x12, struct vhost_vring_state)
#define VHOST_VRING_LITTLE_ENDIAN 0
#define VHOST_VRING_BIG_ENDIAN 1
#define VHOST_SET_VRING_ENDIAN _IOW(VHOST_VIRTIO, 0x13, struct vhost_vring_state)
#define VHOST_GET_VRING_ENDIAN _IOW(VHOST_VIRTIO, 0x14, struct vhost_vring_state)
#define VHOST_SET_VRING_KICK _IOW(VHOST_VIRTIO, 0x20, struct vhost_vring_file)
#define VHOST_SET_VRING_CALL _IOW(VHOST_VIRTIO, 0x21, struct vhost_vring_file)
#define VHOST_SET_VRING_ERR _IOW(VHOST_VIRTIO, 0x22, struct vhost_vring_file)
#define VHOST_SET_VRING_BUSYLOOP_TIMEOUT _IOW(VHOST_VIRTIO, 0x23, struct vhost_vring_state)
#define VHOST_GET_VRING_BUSYLOOP_TIMEOUT _IOW(VHOST_VIRTIO, 0x24, struct vhost_vring_state)
#define VHOST_BACKEND_F_IOTLB_MSG_V2 0x1
#define VHOST_BACKEND_F_IOTLB_BATCH 0x2
#define VHOST_SET_BACKEND_FEATURES _IOW(VHOST_VIRTIO, 0x25, __u64)
#define VHOST_GET_BACKEND_FEATURES _IOR(VHOST_VIRTIO, 0x26, __u64)
#define VHOST_NET_SET_BACKEND _IOW(VHOST_VIRTIO, 0x30, struct vhost_vring_file)
#define VHOST_SCSI_SET_ENDPOINT _IOW(VHOST_VIRTIO, 0x40, struct vhost_scsi_target)
#define VHOST_SCSI_CLEAR_ENDPOINT _IOW(VHOST_VIRTIO, 0x41, struct vhost_scsi_target)
#define VHOST_SCSI_GET_ABI_VERSION _IOW(VHOST_VIRTIO, 0x42, int)
#define VHOST_SCSI_SET_EVENTS_MISSED _IOW(VHOST_VIRTIO, 0x43, __u32)
#define VHOST_SCSI_GET_EVENTS_MISSED _IOW(VHOST_VIRTIO, 0x44, __u32)
#define VHOST_VSOCK_SET_GUEST_CID _IOW(VHOST_VIRTIO, 0x60, __u64)
#define VHOST_VSOCK_SET_RUNNING _IOW(VHOST_VIRTIO, 0x61, int)
#define VHOST_VDPA_GET_DEVICE_ID _IOR(VHOST_VIRTIO, 0x70, __u32)
#define VHOST_VDPA_GET_STATUS _IOR(VHOST_VIRTIO, 0x71, __u8)
#define VHOST_VDPA_SET_STATUS _IOW(VHOST_VIRTIO, 0x72, __u8)
#define VHOST_VDPA_GET_CONFIG _IOR(VHOST_VIRTIO, 0x73, struct vhost_vdpa_config)
#define VHOST_VDPA_SET_CONFIG _IOW(VHOST_VIRTIO, 0x74, struct vhost_vdpa_config)
#define VHOST_VDPA_SET_VRING_ENABLE _IOW(VHOST_VIRTIO, 0x75, struct vhost_vring_state)
#define VHOST_VDPA_GET_VRING_NUM _IOR(VHOST_VIRTIO, 0x76, __u16)
#define VHOST_VDPA_SET_CONFIG_CALL _IOW(VHOST_VIRTIO, 0x77, int)
#define VHOST_VDPA_GET_IOVA_RANGE _IOR(VHOST_VIRTIO, 0x78, struct vhost_vdpa_iova_range)
#endif