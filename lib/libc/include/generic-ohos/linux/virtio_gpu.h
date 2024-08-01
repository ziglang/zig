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
#ifndef VIRTIO_GPU_HW_H
#define VIRTIO_GPU_HW_H
#include <linux/types.h>
#define VIRTIO_GPU_F_VIRGL 0
#define VIRTIO_GPU_F_EDID 1
#define VIRTIO_GPU_F_RESOURCE_UUID 2
enum virtio_gpu_ctrl_type {
  VIRTIO_GPU_UNDEFINED = 0,
  VIRTIO_GPU_CMD_GET_DISPLAY_INFO = 0x0100,
  VIRTIO_GPU_CMD_RESOURCE_CREATE_2D,
  VIRTIO_GPU_CMD_RESOURCE_UNREF,
  VIRTIO_GPU_CMD_SET_SCANOUT,
  VIRTIO_GPU_CMD_RESOURCE_FLUSH,
  VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D,
  VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING,
  VIRTIO_GPU_CMD_RESOURCE_DETACH_BACKING,
  VIRTIO_GPU_CMD_GET_CAPSET_INFO,
  VIRTIO_GPU_CMD_GET_CAPSET,
  VIRTIO_GPU_CMD_GET_EDID,
  VIRTIO_GPU_CMD_RESOURCE_ASSIGN_UUID,
  VIRTIO_GPU_CMD_CTX_CREATE = 0x0200,
  VIRTIO_GPU_CMD_CTX_DESTROY,
  VIRTIO_GPU_CMD_CTX_ATTACH_RESOURCE,
  VIRTIO_GPU_CMD_CTX_DETACH_RESOURCE,
  VIRTIO_GPU_CMD_RESOURCE_CREATE_3D,
  VIRTIO_GPU_CMD_TRANSFER_TO_HOST_3D,
  VIRTIO_GPU_CMD_TRANSFER_FROM_HOST_3D,
  VIRTIO_GPU_CMD_SUBMIT_3D,
  VIRTIO_GPU_CMD_UPDATE_CURSOR = 0x0300,
  VIRTIO_GPU_CMD_MOVE_CURSOR,
  VIRTIO_GPU_RESP_OK_NODATA = 0x1100,
  VIRTIO_GPU_RESP_OK_DISPLAY_INFO,
  VIRTIO_GPU_RESP_OK_CAPSET_INFO,
  VIRTIO_GPU_RESP_OK_CAPSET,
  VIRTIO_GPU_RESP_OK_EDID,
  VIRTIO_GPU_RESP_OK_RESOURCE_UUID,
  VIRTIO_GPU_RESP_ERR_UNSPEC = 0x1200,
  VIRTIO_GPU_RESP_ERR_OUT_OF_MEMORY,
  VIRTIO_GPU_RESP_ERR_INVALID_SCANOUT_ID,
  VIRTIO_GPU_RESP_ERR_INVALID_RESOURCE_ID,
  VIRTIO_GPU_RESP_ERR_INVALID_CONTEXT_ID,
  VIRTIO_GPU_RESP_ERR_INVALID_PARAMETER,
};
#define VIRTIO_GPU_FLAG_FENCE (1 << 0)
struct virtio_gpu_ctrl_hdr {
  __le32 type;
  __le32 flags;
  __le64 fence_id;
  __le32 ctx_id;
  __le32 padding;
};
struct virtio_gpu_cursor_pos {
  __le32 scanout_id;
  __le32 x;
  __le32 y;
  __le32 padding;
};
struct virtio_gpu_update_cursor {
  struct virtio_gpu_ctrl_hdr hdr;
  struct virtio_gpu_cursor_pos pos;
  __le32 resource_id;
  __le32 hot_x;
  __le32 hot_y;
  __le32 padding;
};
struct virtio_gpu_rect {
  __le32 x;
  __le32 y;
  __le32 width;
  __le32 height;
};
struct virtio_gpu_resource_unref {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 resource_id;
  __le32 padding;
};
struct virtio_gpu_resource_create_2d {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 resource_id;
  __le32 format;
  __le32 width;
  __le32 height;
};
struct virtio_gpu_set_scanout {
  struct virtio_gpu_ctrl_hdr hdr;
  struct virtio_gpu_rect r;
  __le32 scanout_id;
  __le32 resource_id;
};
struct virtio_gpu_resource_flush {
  struct virtio_gpu_ctrl_hdr hdr;
  struct virtio_gpu_rect r;
  __le32 resource_id;
  __le32 padding;
};
struct virtio_gpu_transfer_to_host_2d {
  struct virtio_gpu_ctrl_hdr hdr;
  struct virtio_gpu_rect r;
  __le64 offset;
  __le32 resource_id;
  __le32 padding;
};
struct virtio_gpu_mem_entry {
  __le64 addr;
  __le32 length;
  __le32 padding;
};
struct virtio_gpu_resource_attach_backing {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 resource_id;
  __le32 nr_entries;
};
struct virtio_gpu_resource_detach_backing {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 resource_id;
  __le32 padding;
};
#define VIRTIO_GPU_MAX_SCANOUTS 16
struct virtio_gpu_resp_display_info {
  struct virtio_gpu_ctrl_hdr hdr;
  struct virtio_gpu_display_one {
    struct virtio_gpu_rect r;
    __le32 enabled;
    __le32 flags;
  } pmodes[VIRTIO_GPU_MAX_SCANOUTS];
};
struct virtio_gpu_box {
  __le32 x, y, z;
  __le32 w, h, d;
};
struct virtio_gpu_transfer_host_3d {
  struct virtio_gpu_ctrl_hdr hdr;
  struct virtio_gpu_box box;
  __le64 offset;
  __le32 resource_id;
  __le32 level;
  __le32 stride;
  __le32 layer_stride;
};
#define VIRTIO_GPU_RESOURCE_FLAG_Y_0_TOP (1 << 0)
struct virtio_gpu_resource_create_3d {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 resource_id;
  __le32 target;
  __le32 format;
  __le32 bind;
  __le32 width;
  __le32 height;
  __le32 depth;
  __le32 array_size;
  __le32 last_level;
  __le32 nr_samples;
  __le32 flags;
  __le32 padding;
};
struct virtio_gpu_ctx_create {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 nlen;
  __le32 padding;
  char debug_name[64];
};
struct virtio_gpu_ctx_destroy {
  struct virtio_gpu_ctrl_hdr hdr;
};
struct virtio_gpu_ctx_resource {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 resource_id;
  __le32 padding;
};
struct virtio_gpu_cmd_submit {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 size;
  __le32 padding;
};
#define VIRTIO_GPU_CAPSET_VIRGL 1
#define VIRTIO_GPU_CAPSET_VIRGL2 2
struct virtio_gpu_get_capset_info {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 capset_index;
  __le32 padding;
};
struct virtio_gpu_resp_capset_info {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 capset_id;
  __le32 capset_max_version;
  __le32 capset_max_size;
  __le32 padding;
};
struct virtio_gpu_get_capset {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 capset_id;
  __le32 capset_version;
};
struct virtio_gpu_resp_capset {
  struct virtio_gpu_ctrl_hdr hdr;
  __u8 capset_data[];
};
struct virtio_gpu_cmd_get_edid {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 scanout;
  __le32 padding;
};
struct virtio_gpu_resp_edid {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 size;
  __le32 padding;
  __u8 edid[1024];
};
#define VIRTIO_GPU_EVENT_DISPLAY (1 << 0)
struct virtio_gpu_config {
  __le32 events_read;
  __le32 events_clear;
  __le32 num_scanouts;
  __le32 num_capsets;
};
enum virtio_gpu_formats {
  VIRTIO_GPU_FORMAT_B8G8R8A8_UNORM = 1,
  VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM = 2,
  VIRTIO_GPU_FORMAT_A8R8G8B8_UNORM = 3,
  VIRTIO_GPU_FORMAT_X8R8G8B8_UNORM = 4,
  VIRTIO_GPU_FORMAT_R8G8B8A8_UNORM = 67,
  VIRTIO_GPU_FORMAT_X8B8G8R8_UNORM = 68,
  VIRTIO_GPU_FORMAT_A8B8G8R8_UNORM = 121,
  VIRTIO_GPU_FORMAT_R8G8B8X8_UNORM = 134,
};
struct virtio_gpu_resource_assign_uuid {
  struct virtio_gpu_ctrl_hdr hdr;
  __le32 resource_id;
  __le32 padding;
};
struct virtio_gpu_resp_resource_uuid {
  struct virtio_gpu_ctrl_hdr hdr;
  __u8 uuid[16];
};
#endif