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
#ifndef __SOUND_HDSPM_H
#define __SOUND_HDSPM_H
#ifdef __linux__
#include <linux/types.h>
#endif
#define HDSPM_MAX_CHANNELS 64
enum hdspm_io_type {
  MADI,
  MADIface,
  AIO,
  AES32,
  RayDAT
};
enum hdspm_speed {
  ss,
  ds,
  qs
};
struct hdspm_peak_rms {
  __u32 input_peaks[64];
  __u32 playback_peaks[64];
  __u32 output_peaks[64];
  __u64 input_rms[64];
  __u64 playback_rms[64];
  __u64 output_rms[64];
  __u8 speed;
  int status2;
};
#define SNDRV_HDSPM_IOCTL_GET_PEAK_RMS _IOR('H', 0x42, struct hdspm_peak_rms)
struct hdspm_config {
  unsigned char pref_sync_ref;
  unsigned char wordclock_sync_check;
  unsigned char madi_sync_check;
  unsigned int system_sample_rate;
  unsigned int autosync_sample_rate;
  unsigned char system_clock_mode;
  unsigned char clock_source;
  unsigned char autosync_ref;
  unsigned char line_out;
  unsigned int passthru;
  unsigned int analog_out;
};
#define SNDRV_HDSPM_IOCTL_GET_CONFIG _IOR('H', 0x41, struct hdspm_config)
enum hdspm_ltc_format {
  format_invalid,
  fps_24,
  fps_25,
  fps_2997,
  fps_30
};
enum hdspm_ltc_frame {
  frame_invalid,
  drop_frame,
  full_frame
};
enum hdspm_ltc_input_format {
  ntsc,
  pal,
  no_video
};
struct hdspm_ltc {
  unsigned int ltc;
  enum hdspm_ltc_format format;
  enum hdspm_ltc_frame frame;
  enum hdspm_ltc_input_format input_format;
};
#define SNDRV_HDSPM_IOCTL_GET_LTC _IOR('H', 0x46, struct hdspm_ltc)
enum hdspm_sync {
  hdspm_sync_no_lock = 0,
  hdspm_sync_lock = 1,
  hdspm_sync_sync = 2
};
enum hdspm_madi_input {
  hdspm_input_optical = 0,
  hdspm_input_coax = 1
};
enum hdspm_madi_channel_format {
  hdspm_format_ch_64 = 0,
  hdspm_format_ch_56 = 1
};
enum hdspm_madi_frame_format {
  hdspm_frame_48 = 0,
  hdspm_frame_96 = 1
};
enum hdspm_syncsource {
  syncsource_wc = 0,
  syncsource_madi = 1,
  syncsource_tco = 2,
  syncsource_sync = 3,
  syncsource_none = 4
};
struct hdspm_status {
  __u8 card_type;
  enum hdspm_syncsource autosync_source;
  __u64 card_clock;
  __u32 master_period;
  union {
    struct {
      __u8 sync_wc;
      __u8 sync_madi;
      __u8 sync_tco;
      __u8 sync_in;
      __u8 madi_input;
      __u8 channel_format;
      __u8 frame_format;
    } madi;
  } card_specific;
};
#define SNDRV_HDSPM_IOCTL_GET_STATUS _IOR('H', 0x47, struct hdspm_status)
#define HDSPM_ADDON_TCO 1
struct hdspm_version {
  __u8 card_type;
  char cardname[20];
  unsigned int serial;
  unsigned short firmware_rev;
  int addons;
};
#define SNDRV_HDSPM_IOCTL_GET_VERSION _IOR('H', 0x48, struct hdspm_version)
#define HDSPM_MIXER_CHANNELS HDSPM_MAX_CHANNELS
struct hdspm_channelfader {
  unsigned int in[HDSPM_MIXER_CHANNELS];
  unsigned int pb[HDSPM_MIXER_CHANNELS];
};
struct hdspm_mixer {
  struct hdspm_channelfader ch[HDSPM_MIXER_CHANNELS];
};
struct hdspm_mixer_ioctl {
  struct hdspm_mixer * mixer;
};
#define SNDRV_HDSPM_IOCTL_GET_MIXER _IOR('H', 0x44, struct hdspm_mixer_ioctl)
#endif