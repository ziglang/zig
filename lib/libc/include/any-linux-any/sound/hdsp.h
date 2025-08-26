/* SPDX-License-Identifier: GPL-2.0+ WITH Linux-syscall-note */
#ifndef __SOUND_HDSP_H
#define __SOUND_HDSP_H

/*
 *   Copyright (C) 2003 Thomas Charbonnel (thomas@undata.org)
 */

#ifdef __linux__
#include <linux/types.h>
#endif

#define HDSP_MATRIX_MIXER_SIZE 2048

enum HDSP_IO_Type {
	Digiface,
	Multiface,
	H9652,
	H9632,
	RPM,
	Undefined,
};

struct hdsp_peak_rms {
	__u32 input_peaks[26];
	__u32 playback_peaks[26];
	__u32 output_peaks[28];
	__u64 input_rms[26];
	__u64 playback_rms[26];
	/* These are only used for H96xx cards */
	__u64 output_rms[26];
};

#define SNDRV_HDSP_IOCTL_GET_PEAK_RMS _IOR('H', 0x40, struct hdsp_peak_rms)

struct hdsp_config_info {
	unsigned char pref_sync_ref;
	unsigned char wordclock_sync_check;
	unsigned char spdif_sync_check;
	unsigned char adatsync_sync_check;
	unsigned char adat_sync_check[3];
	unsigned char spdif_in;
	unsigned char spdif_out;
	unsigned char spdif_professional;
	unsigned char spdif_emphasis;
	unsigned char spdif_nonaudio;
	unsigned int spdif_sample_rate;
	unsigned int system_sample_rate;
	unsigned int autosync_sample_rate;
	unsigned char system_clock_mode;
	unsigned char clock_source;
	unsigned char autosync_ref;
	unsigned char line_out;
	unsigned char passthru; 
	unsigned char da_gain;
	unsigned char ad_gain;
	unsigned char phone_gain;
	unsigned char xlr_breakout_cable;
	unsigned char analog_extension_board;
};

#define SNDRV_HDSP_IOCTL_GET_CONFIG_INFO _IOR('H', 0x41, struct hdsp_config_info)

struct hdsp_firmware {
	void *firmware_data;	/* 24413 x 4 bytes */
};

#define SNDRV_HDSP_IOCTL_UPLOAD_FIRMWARE _IOW('H', 0x42, struct hdsp_firmware)

struct hdsp_version {
	enum HDSP_IO_Type io_type;
	unsigned short firmware_rev;
};

#define SNDRV_HDSP_IOCTL_GET_VERSION _IOR('H', 0x43, struct hdsp_version)

struct hdsp_mixer {
	unsigned short matrix[HDSP_MATRIX_MIXER_SIZE];
};

#define SNDRV_HDSP_IOCTL_GET_MIXER _IOR('H', 0x44, struct hdsp_mixer)

struct hdsp_9632_aeb {
	int aebi;
	int aebo;
};

#define SNDRV_HDSP_IOCTL_GET_9632_AEB _IOR('H', 0x45, struct hdsp_9632_aeb)

#endif /* __SOUND_HDSP_H */