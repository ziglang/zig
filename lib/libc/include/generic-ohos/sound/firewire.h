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
#ifndef _UAPI_SOUND_FIREWIRE_H_INCLUDED
#define _UAPI_SOUND_FIREWIRE_H_INCLUDED
#include <linux/ioctl.h>
#include <linux/types.h>
#define SNDRV_FIREWIRE_EVENT_LOCK_STATUS 0x000010cc
#define SNDRV_FIREWIRE_EVENT_DICE_NOTIFICATION 0xd1ce004e
#define SNDRV_FIREWIRE_EVENT_EFW_RESPONSE 0x4e617475
#define SNDRV_FIREWIRE_EVENT_DIGI00X_MESSAGE 0x746e736c
#define SNDRV_FIREWIRE_EVENT_MOTU_NOTIFICATION 0x64776479
#define SNDRV_FIREWIRE_EVENT_TASCAM_CONTROL 0x7473636d
struct snd_firewire_event_common {
  unsigned int type;
};
struct snd_firewire_event_lock_status {
  unsigned int type;
  unsigned int status;
};
struct snd_firewire_event_dice_notification {
  unsigned int type;
  unsigned int notification;
};
#define SND_EFW_TRANSACTION_USER_SEQNUM_MAX ((__u32) ((__u16) ~0) - 1)
struct snd_efw_transaction {
  __be32 length;
  __be32 version;
  __be32 seqnum;
  __be32 category;
  __be32 command;
  __be32 status;
  __be32 params[0];
};
struct snd_firewire_event_efw_response {
  unsigned int type;
  __be32 response[0];
};
struct snd_firewire_event_digi00x_message {
  unsigned int type;
  __u32 message;
};
struct snd_firewire_event_motu_notification {
  unsigned int type;
  __u32 message;
};
struct snd_firewire_tascam_change {
  unsigned int index;
  __be32 before;
  __be32 after;
};
struct snd_firewire_event_tascam_control {
  unsigned int type;
  struct snd_firewire_tascam_change changes[0];
};
union snd_firewire_event {
  struct snd_firewire_event_common common;
  struct snd_firewire_event_lock_status lock_status;
  struct snd_firewire_event_dice_notification dice_notification;
  struct snd_firewire_event_efw_response efw_response;
  struct snd_firewire_event_digi00x_message digi00x_message;
  struct snd_firewire_event_tascam_control tascam_control;
  struct snd_firewire_event_motu_notification motu_notification;
};
#define SNDRV_FIREWIRE_IOCTL_GET_INFO _IOR('H', 0xf8, struct snd_firewire_get_info)
#define SNDRV_FIREWIRE_IOCTL_LOCK _IO('H', 0xf9)
#define SNDRV_FIREWIRE_IOCTL_UNLOCK _IO('H', 0xfa)
#define SNDRV_FIREWIRE_IOCTL_TASCAM_STATE _IOR('H', 0xfb, struct snd_firewire_tascam_state)
#define SNDRV_FIREWIRE_TYPE_DICE 1
#define SNDRV_FIREWIRE_TYPE_FIREWORKS 2
#define SNDRV_FIREWIRE_TYPE_BEBOB 3
#define SNDRV_FIREWIRE_TYPE_OXFW 4
#define SNDRV_FIREWIRE_TYPE_DIGI00X 5
#define SNDRV_FIREWIRE_TYPE_TASCAM 6
#define SNDRV_FIREWIRE_TYPE_MOTU 7
#define SNDRV_FIREWIRE_TYPE_FIREFACE 8
struct snd_firewire_get_info {
  unsigned int type;
  unsigned int card;
  unsigned char guid[8];
  char device_name[16];
};
#define SNDRV_FIREWIRE_TASCAM_STATE_COUNT 64
struct snd_firewire_tascam_state {
  __be32 data[SNDRV_FIREWIRE_TASCAM_STATE_COUNT];
};
#endif