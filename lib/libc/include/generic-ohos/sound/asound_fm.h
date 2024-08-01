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
#ifndef __SOUND_ASOUND_FM_H
#define __SOUND_ASOUND_FM_H
#define SNDRV_DM_FM_MODE_OPL2 0x00
#define SNDRV_DM_FM_MODE_OPL3 0x01
struct snd_dm_fm_info {
  unsigned char fm_mode;
  unsigned char rhythm;
};
struct snd_dm_fm_voice {
  unsigned char op;
  unsigned char voice;
  unsigned char am;
  unsigned char vibrato;
  unsigned char do_sustain;
  unsigned char kbd_scale;
  unsigned char harmonic;
  unsigned char scale_level;
  unsigned char volume;
  unsigned char attack;
  unsigned char decay;
  unsigned char sustain;
  unsigned char release;
  unsigned char feedback;
  unsigned char connection;
  unsigned char left;
  unsigned char right;
  unsigned char waveform;
};
struct snd_dm_fm_note {
  unsigned char voice;
  unsigned char octave;
  unsigned int fnum;
  unsigned char key_on;
};
struct snd_dm_fm_params {
  unsigned char am_depth;
  unsigned char vib_depth;
  unsigned char kbd_split;
  unsigned char rhythm;
  unsigned char bass;
  unsigned char snare;
  unsigned char tomtom;
  unsigned char cymbal;
  unsigned char hihat;
};
#define SNDRV_DM_FM_IOCTL_INFO _IOR('H', 0x20, struct snd_dm_fm_info)
#define SNDRV_DM_FM_IOCTL_RESET _IO('H', 0x21)
#define SNDRV_DM_FM_IOCTL_PLAY_NOTE _IOW('H', 0x22, struct snd_dm_fm_note)
#define SNDRV_DM_FM_IOCTL_SET_VOICE _IOW('H', 0x23, struct snd_dm_fm_voice)
#define SNDRV_DM_FM_IOCTL_SET_PARAMS _IOW('H', 0x24, struct snd_dm_fm_params)
#define SNDRV_DM_FM_IOCTL_SET_MODE _IOW('H', 0x25, int)
#define SNDRV_DM_FM_IOCTL_SET_CONNECTION _IOW('H', 0x26, int)
#define SNDRV_DM_FM_IOCTL_CLEAR_PATCHES _IO('H', 0x40)
#define SNDRV_DM_FM_OSS_IOCTL_RESET 0x20
#define SNDRV_DM_FM_OSS_IOCTL_PLAY_NOTE 0x21
#define SNDRV_DM_FM_OSS_IOCTL_SET_VOICE 0x22
#define SNDRV_DM_FM_OSS_IOCTL_SET_PARAMS 0x23
#define SNDRV_DM_FM_OSS_IOCTL_SET_MODE 0x24
#define SNDRV_DM_FM_OSS_IOCTL_SET_OPL 0x25
#define FM_KEY_SBI "SBI\032"
#define FM_KEY_2OP "2OP\032"
#define FM_KEY_4OP "4OP\032"
struct sbi_patch {
  unsigned char prog;
  unsigned char bank;
  char key[4];
  char name[25];
  char extension[7];
  unsigned char data[32];
};
#endif