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
#ifndef __UAPI_SOUND_TLV_H
#define __UAPI_SOUND_TLV_H
#define SNDRV_CTL_TLVT_CONTAINER 0
#define SNDRV_CTL_TLVT_DB_SCALE 1
#define SNDRV_CTL_TLVT_DB_LINEAR 2
#define SNDRV_CTL_TLVT_DB_RANGE 3
#define SNDRV_CTL_TLVT_DB_MINMAX 4
#define SNDRV_CTL_TLVT_DB_MINMAX_MUTE 5
#define SNDRV_CTL_TLVT_CHMAP_FIXED 0x101
#define SNDRV_CTL_TLVT_CHMAP_VAR 0x102
#define SNDRV_CTL_TLVT_CHMAP_PAIRED 0x103
#define SNDRV_CTL_TLVD_ITEM(type,...) (type), SNDRV_CTL_TLVD_LENGTH(__VA_ARGS__), __VA_ARGS__
#define SNDRV_CTL_TLVD_LENGTH(...) ((unsigned int) sizeof((const unsigned int[]) { __VA_ARGS__ }))
#define SNDRV_CTL_TLVO_TYPE 0
#define SNDRV_CTL_TLVO_LEN 1
#define SNDRV_CTL_TLVD_CONTAINER_ITEM(...) SNDRV_CTL_TLVD_ITEM(SNDRV_CTL_TLVT_CONTAINER, __VA_ARGS__)
#define SNDRV_CTL_TLVD_DECLARE_CONTAINER(name,...) unsigned int name[] = { SNDRV_CTL_TLVD_CONTAINER_ITEM(__VA_ARGS__) }
#define SNDRV_CTL_TLVD_DB_SCALE_MASK 0xffff
#define SNDRV_CTL_TLVD_DB_SCALE_MUTE 0x10000
#define SNDRV_CTL_TLVD_DB_SCALE_ITEM(min,step,mute) SNDRV_CTL_TLVD_ITEM(SNDRV_CTL_TLVT_DB_SCALE, (min), ((step) & SNDRV_CTL_TLVD_DB_SCALE_MASK) | ((mute) ? SNDRV_CTL_TLVD_DB_SCALE_MUTE : 0))
#define SNDRV_CTL_TLVD_DECLARE_DB_SCALE(name,min,step,mute) unsigned int name[] = { SNDRV_CTL_TLVD_DB_SCALE_ITEM(min, step, mute) }
#define SNDRV_CTL_TLVO_DB_SCALE_MIN 2
#define SNDRV_CTL_TLVO_DB_SCALE_MUTE_AND_STEP 3
#define SNDRV_CTL_TLVD_DB_MINMAX_ITEM(min_dB,max_dB) SNDRV_CTL_TLVD_ITEM(SNDRV_CTL_TLVT_DB_MINMAX, (min_dB), (max_dB))
#define SNDRV_CTL_TLVD_DB_MINMAX_MUTE_ITEM(min_dB,max_dB) SNDRV_CTL_TLVD_ITEM(SNDRV_CTL_TLVT_DB_MINMAX_MUTE, (min_dB), (max_dB))
#define SNDRV_CTL_TLVD_DECLARE_DB_MINMAX(name,min_dB,max_dB) unsigned int name[] = { SNDRV_CTL_TLVD_DB_MINMAX_ITEM(min_dB, max_dB) }
#define SNDRV_CTL_TLVD_DECLARE_DB_MINMAX_MUTE(name,min_dB,max_dB) unsigned int name[] = { SNDRV_CTL_TLVD_DB_MINMAX_MUTE_ITEM(min_dB, max_dB) }
#define SNDRV_CTL_TLVO_DB_MINMAX_MIN 2
#define SNDRV_CTL_TLVO_DB_MINMAX_MAX 3
#define SNDRV_CTL_TLVD_DB_LINEAR_ITEM(min_dB,max_dB) SNDRV_CTL_TLVD_ITEM(SNDRV_CTL_TLVT_DB_LINEAR, (min_dB), (max_dB))
#define SNDRV_CTL_TLVD_DECLARE_DB_LINEAR(name,min_dB,max_dB) unsigned int name[] = { SNDRV_CTL_TLVD_DB_LINEAR_ITEM(min_dB, max_dB) }
#define SNDRV_CTL_TLVO_DB_LINEAR_MIN 2
#define SNDRV_CTL_TLVO_DB_LINEAR_MAX 3
#define SNDRV_CTL_TLVD_DB_RANGE_ITEM(...) SNDRV_CTL_TLVD_ITEM(SNDRV_CTL_TLVT_DB_RANGE, __VA_ARGS__)
#define SNDRV_CTL_TLVD_DECLARE_DB_RANGE(name,...) unsigned int name[] = { SNDRV_CTL_TLVD_DB_RANGE_ITEM(__VA_ARGS__) }
#define SNDRV_CTL_TLVD_DB_GAIN_MUTE - 9999999
#endif