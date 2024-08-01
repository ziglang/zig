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
#ifndef __LINUX_MEDIA_H
#define __LINUX_MEDIA_H
#include <stdint.h>
#include <linux/ioctl.h>
#include <linux/types.h>
struct media_device_info {
  char driver[16];
  char model[32];
  char serial[40];
  char bus_info[32];
  __u32 media_version;
  __u32 hw_revision;
  __u32 driver_version;
  __u32 reserved[31];
};
#define MEDIA_ENT_F_BASE 0x00000000
#define MEDIA_ENT_F_OLD_BASE 0x00010000
#define MEDIA_ENT_F_OLD_SUBDEV_BASE 0x00020000
#define MEDIA_ENT_F_UNKNOWN MEDIA_ENT_F_BASE
#define MEDIA_ENT_F_V4L2_SUBDEV_UNKNOWN MEDIA_ENT_F_OLD_SUBDEV_BASE
#define MEDIA_ENT_F_DTV_DEMOD (MEDIA_ENT_F_BASE + 0x00001)
#define MEDIA_ENT_F_TS_DEMUX (MEDIA_ENT_F_BASE + 0x00002)
#define MEDIA_ENT_F_DTV_CA (MEDIA_ENT_F_BASE + 0x00003)
#define MEDIA_ENT_F_DTV_NET_DECAP (MEDIA_ENT_F_BASE + 0x00004)
#define MEDIA_ENT_F_IO_V4L (MEDIA_ENT_F_OLD_BASE + 1)
#define MEDIA_ENT_F_IO_DTV (MEDIA_ENT_F_BASE + 0x01001)
#define MEDIA_ENT_F_IO_VBI (MEDIA_ENT_F_BASE + 0x01002)
#define MEDIA_ENT_F_IO_SWRADIO (MEDIA_ENT_F_BASE + 0x01003)
#define MEDIA_ENT_F_CAM_SENSOR (MEDIA_ENT_F_OLD_SUBDEV_BASE + 1)
#define MEDIA_ENT_F_FLASH (MEDIA_ENT_F_OLD_SUBDEV_BASE + 2)
#define MEDIA_ENT_F_LENS (MEDIA_ENT_F_OLD_SUBDEV_BASE + 3)
#define MEDIA_ENT_F_TUNER (MEDIA_ENT_F_OLD_SUBDEV_BASE + 5)
#define MEDIA_ENT_F_IF_VID_DECODER (MEDIA_ENT_F_BASE + 0x02001)
#define MEDIA_ENT_F_IF_AUD_DECODER (MEDIA_ENT_F_BASE + 0x02002)
#define MEDIA_ENT_F_AUDIO_CAPTURE (MEDIA_ENT_F_BASE + 0x03001)
#define MEDIA_ENT_F_AUDIO_PLAYBACK (MEDIA_ENT_F_BASE + 0x03002)
#define MEDIA_ENT_F_AUDIO_MIXER (MEDIA_ENT_F_BASE + 0x03003)
#define MEDIA_ENT_F_PROC_VIDEO_COMPOSER (MEDIA_ENT_F_BASE + 0x4001)
#define MEDIA_ENT_F_PROC_VIDEO_PIXEL_FORMATTER (MEDIA_ENT_F_BASE + 0x4002)
#define MEDIA_ENT_F_PROC_VIDEO_PIXEL_ENC_CONV (MEDIA_ENT_F_BASE + 0x4003)
#define MEDIA_ENT_F_PROC_VIDEO_LUT (MEDIA_ENT_F_BASE + 0x4004)
#define MEDIA_ENT_F_PROC_VIDEO_SCALER (MEDIA_ENT_F_BASE + 0x4005)
#define MEDIA_ENT_F_PROC_VIDEO_STATISTICS (MEDIA_ENT_F_BASE + 0x4006)
#define MEDIA_ENT_F_PROC_VIDEO_ENCODER (MEDIA_ENT_F_BASE + 0x4007)
#define MEDIA_ENT_F_PROC_VIDEO_DECODER (MEDIA_ENT_F_BASE + 0x4008)
#define MEDIA_ENT_F_VID_MUX (MEDIA_ENT_F_BASE + 0x5001)
#define MEDIA_ENT_F_VID_IF_BRIDGE (MEDIA_ENT_F_BASE + 0x5002)
#define MEDIA_ENT_F_ATV_DECODER (MEDIA_ENT_F_OLD_SUBDEV_BASE + 4)
#define MEDIA_ENT_F_DV_DECODER (MEDIA_ENT_F_BASE + 0x6001)
#define MEDIA_ENT_F_DV_ENCODER (MEDIA_ENT_F_BASE + 0x6002)
#define MEDIA_ENT_FL_DEFAULT (1 << 0)
#define MEDIA_ENT_FL_CONNECTOR (1 << 1)
#define MEDIA_ENT_ID_FLAG_NEXT (1U << 31)
struct media_entity_desc {
  __u32 id;
  char name[32];
  __u32 type;
  __u32 revision;
  __u32 flags;
  __u32 group_id;
  __u16 pads;
  __u16 links;
  __u32 reserved[4];
  union {
    struct {
      __u32 major;
      __u32 minor;
    } dev;
    struct {
      __u32 card;
      __u32 device;
      __u32 subdevice;
    } alsa;
    struct {
      __u32 major;
      __u32 minor;
    } v4l;
    struct {
      __u32 major;
      __u32 minor;
    } fb;
    int dvb;
    __u8 raw[184];
  };
};
#define MEDIA_PAD_FL_SINK (1 << 0)
#define MEDIA_PAD_FL_SOURCE (1 << 1)
#define MEDIA_PAD_FL_MUST_CONNECT (1 << 2)
struct media_pad_desc {
  __u32 entity;
  __u16 index;
  __u32 flags;
  __u32 reserved[2];
};
#define MEDIA_LNK_FL_ENABLED (1 << 0)
#define MEDIA_LNK_FL_IMMUTABLE (1 << 1)
#define MEDIA_LNK_FL_DYNAMIC (1 << 2)
#define MEDIA_LNK_FL_LINK_TYPE (0xf << 28)
#define MEDIA_LNK_FL_DATA_LINK (0 << 28)
#define MEDIA_LNK_FL_INTERFACE_LINK (1 << 28)
struct media_link_desc {
  struct media_pad_desc source;
  struct media_pad_desc sink;
  __u32 flags;
  __u32 reserved[2];
};
struct media_links_enum {
  __u32 entity;
  struct media_pad_desc __user * pads;
  struct media_link_desc __user * links;
  __u32 reserved[4];
};
#define MEDIA_INTF_T_DVB_BASE 0x00000100
#define MEDIA_INTF_T_V4L_BASE 0x00000200
#define MEDIA_INTF_T_DVB_FE (MEDIA_INTF_T_DVB_BASE)
#define MEDIA_INTF_T_DVB_DEMUX (MEDIA_INTF_T_DVB_BASE + 1)
#define MEDIA_INTF_T_DVB_DVR (MEDIA_INTF_T_DVB_BASE + 2)
#define MEDIA_INTF_T_DVB_CA (MEDIA_INTF_T_DVB_BASE + 3)
#define MEDIA_INTF_T_DVB_NET (MEDIA_INTF_T_DVB_BASE + 4)
#define MEDIA_INTF_T_V4L_VIDEO (MEDIA_INTF_T_V4L_BASE)
#define MEDIA_INTF_T_V4L_VBI (MEDIA_INTF_T_V4L_BASE + 1)
#define MEDIA_INTF_T_V4L_RADIO (MEDIA_INTF_T_V4L_BASE + 2)
#define MEDIA_INTF_T_V4L_SUBDEV (MEDIA_INTF_T_V4L_BASE + 3)
#define MEDIA_INTF_T_V4L_SWRADIO (MEDIA_INTF_T_V4L_BASE + 4)
#define MEDIA_INTF_T_V4L_TOUCH (MEDIA_INTF_T_V4L_BASE + 5)
#define MEDIA_INTF_T_ALSA_BASE 0x00000300
#define MEDIA_INTF_T_ALSA_PCM_CAPTURE (MEDIA_INTF_T_ALSA_BASE)
#define MEDIA_INTF_T_ALSA_PCM_PLAYBACK (MEDIA_INTF_T_ALSA_BASE + 1)
#define MEDIA_INTF_T_ALSA_CONTROL (MEDIA_INTF_T_ALSA_BASE + 2)
#define MEDIA_V2_ENTITY_HAS_FLAGS(media_version) ((media_version) >= ((4 << 16) | (19 << 8) | 0))
struct media_v2_entity {
  __u32 id;
  char name[64];
  __u32 function;
  __u32 flags;
  __u32 reserved[5];
} __attribute__((packed));
struct media_v2_intf_devnode {
  __u32 major;
  __u32 minor;
} __attribute__((packed));
struct media_v2_interface {
  __u32 id;
  __u32 intf_type;
  __u32 flags;
  __u32 reserved[9];
  union {
    struct media_v2_intf_devnode devnode;
    __u32 raw[16];
  };
} __attribute__((packed));
#define MEDIA_V2_PAD_HAS_INDEX(media_version) ((media_version) >= ((4 << 16) | (19 << 8) | 0))
struct media_v2_pad {
  __u32 id;
  __u32 entity_id;
  __u32 flags;
  __u32 index;
  __u32 reserved[4];
} __attribute__((packed));
struct media_v2_link {
  __u32 id;
  __u32 source_id;
  __u32 sink_id;
  __u32 flags;
  __u32 reserved[6];
} __attribute__((packed));
struct media_v2_topology {
  __u64 topology_version;
  __u32 num_entities;
  __u32 reserved1;
  __u64 ptr_entities;
  __u32 num_interfaces;
  __u32 reserved2;
  __u64 ptr_interfaces;
  __u32 num_pads;
  __u32 reserved3;
  __u64 ptr_pads;
  __u32 num_links;
  __u32 reserved4;
  __u64 ptr_links;
} __attribute__((packed));
#define MEDIA_IOC_DEVICE_INFO _IOWR('|', 0x00, struct media_device_info)
#define MEDIA_IOC_ENUM_ENTITIES _IOWR('|', 0x01, struct media_entity_desc)
#define MEDIA_IOC_ENUM_LINKS _IOWR('|', 0x02, struct media_links_enum)
#define MEDIA_IOC_SETUP_LINK _IOWR('|', 0x03, struct media_link_desc)
#define MEDIA_IOC_G_TOPOLOGY _IOWR('|', 0x04, struct media_v2_topology)
#define MEDIA_IOC_REQUEST_ALLOC _IOR('|', 0x05, int)
#define MEDIA_REQUEST_IOC_QUEUE _IO('|', 0x80)
#define MEDIA_REQUEST_IOC_REINIT _IO('|', 0x81)
#define MEDIA_ENT_TYPE_SHIFT 16
#define MEDIA_ENT_TYPE_MASK 0x00ff0000
#define MEDIA_ENT_SUBTYPE_MASK 0x0000ffff
#define MEDIA_ENT_T_DEVNODE_UNKNOWN (MEDIA_ENT_F_OLD_BASE | MEDIA_ENT_SUBTYPE_MASK)
#define MEDIA_ENT_T_DEVNODE MEDIA_ENT_F_OLD_BASE
#define MEDIA_ENT_T_DEVNODE_V4L MEDIA_ENT_F_IO_V4L
#define MEDIA_ENT_T_DEVNODE_FB (MEDIA_ENT_F_OLD_BASE + 2)
#define MEDIA_ENT_T_DEVNODE_ALSA (MEDIA_ENT_F_OLD_BASE + 3)
#define MEDIA_ENT_T_DEVNODE_DVB (MEDIA_ENT_F_OLD_BASE + 4)
#define MEDIA_ENT_T_UNKNOWN MEDIA_ENT_F_UNKNOWN
#define MEDIA_ENT_T_V4L2_VIDEO MEDIA_ENT_F_IO_V4L
#define MEDIA_ENT_T_V4L2_SUBDEV MEDIA_ENT_F_V4L2_SUBDEV_UNKNOWN
#define MEDIA_ENT_T_V4L2_SUBDEV_SENSOR MEDIA_ENT_F_CAM_SENSOR
#define MEDIA_ENT_T_V4L2_SUBDEV_FLASH MEDIA_ENT_F_FLASH
#define MEDIA_ENT_T_V4L2_SUBDEV_LENS MEDIA_ENT_F_LENS
#define MEDIA_ENT_T_V4L2_SUBDEV_DECODER MEDIA_ENT_F_ATV_DECODER
#define MEDIA_ENT_T_V4L2_SUBDEV_TUNER MEDIA_ENT_F_TUNER
#define MEDIA_ENT_F_DTV_DECODER MEDIA_ENT_F_DV_DECODER
#define MEDIA_INTF_T_ALSA_COMPRESS (MEDIA_INTF_T_ALSA_BASE + 3)
#define MEDIA_INTF_T_ALSA_RAWMIDI (MEDIA_INTF_T_ALSA_BASE + 4)
#define MEDIA_INTF_T_ALSA_HWDEP (MEDIA_INTF_T_ALSA_BASE + 5)
#define MEDIA_INTF_T_ALSA_SEQUENCER (MEDIA_INTF_T_ALSA_BASE + 6)
#define MEDIA_INTF_T_ALSA_TIMER (MEDIA_INTF_T_ALSA_BASE + 7)
#define MEDIA_API_VERSION ((0 << 16) | (1 << 8) | 0)
#endif