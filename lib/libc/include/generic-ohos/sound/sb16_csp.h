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
#ifndef _UAPI__SOUND_SB16_CSP_H
#define _UAPI__SOUND_SB16_CSP_H
#define SNDRV_SB_CSP_MODE_NONE 0x00
#define SNDRV_SB_CSP_MODE_DSP_READ 0x01
#define SNDRV_SB_CSP_MODE_DSP_WRITE 0x02
#define SNDRV_SB_CSP_MODE_QSOUND 0x04
#define SNDRV_SB_CSP_LOAD_FROMUSER 0x01
#define SNDRV_SB_CSP_LOAD_INITBLOCK 0x02
#define SNDRV_SB_CSP_SAMPLE_8BIT 0x01
#define SNDRV_SB_CSP_SAMPLE_16BIT 0x02
#define SNDRV_SB_CSP_MONO 0x01
#define SNDRV_SB_CSP_STEREO 0x02
#define SNDRV_SB_CSP_RATE_8000 0x01
#define SNDRV_SB_CSP_RATE_11025 0x02
#define SNDRV_SB_CSP_RATE_22050 0x04
#define SNDRV_SB_CSP_RATE_44100 0x08
#define SNDRV_SB_CSP_RATE_ALL 0x0f
#define SNDRV_SB_CSP_ST_IDLE 0x00
#define SNDRV_SB_CSP_ST_LOADED 0x01
#define SNDRV_SB_CSP_ST_RUNNING 0x02
#define SNDRV_SB_CSP_ST_PAUSED 0x04
#define SNDRV_SB_CSP_ST_AUTO 0x08
#define SNDRV_SB_CSP_ST_QSOUND 0x10
#define SNDRV_SB_CSP_QSOUND_MAX_RIGHT 0x20
#define SNDRV_SB_CSP_MAX_MICROCODE_FILE_SIZE 0x3000
struct snd_sb_csp_mc_header {
  char codec_name[16];
  unsigned short func_req;
};
struct snd_sb_csp_microcode {
  struct snd_sb_csp_mc_header info;
  unsigned char data[SNDRV_SB_CSP_MAX_MICROCODE_FILE_SIZE];
};
struct snd_sb_csp_start {
  int sample_width;
  int channels;
};
struct snd_sb_csp_info {
  char codec_name[16];
  unsigned short func_nr;
  unsigned int acc_format;
  unsigned short acc_channels;
  unsigned short acc_width;
  unsigned short acc_rates;
  unsigned short csp_mode;
  unsigned short run_channels;
  unsigned short run_width;
  unsigned short version;
  unsigned short state;
};
#define SNDRV_SB_CSP_IOCTL_INFO _IOR('H', 0x10, struct snd_sb_csp_info)
#define SNDRV_SB_CSP_IOCTL_LOAD_CODE _IOC(_IOC_WRITE, 'H', 0x11, sizeof(struct snd_sb_csp_microcode))
#define SNDRV_SB_CSP_IOCTL_UNLOAD_CODE _IO('H', 0x12)
#define SNDRV_SB_CSP_IOCTL_START _IOW('H', 0x13, struct snd_sb_csp_start)
#define SNDRV_SB_CSP_IOCTL_STOP _IO('H', 0x14)
#define SNDRV_SB_CSP_IOCTL_PAUSE _IO('H', 0x15)
#define SNDRV_SB_CSP_IOCTL_RESTART _IO('H', 0x16)
#endif