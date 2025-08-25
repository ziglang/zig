/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _DVDEVCOD_H
#define _DVDEVCOD_H

#ifdef __cplusplus
extern "C" {
#endif

#define EC_DVD_ANGLE_CHANGE 0x0106
#define EC_DVD_ANGLES_AVAILABLE 0x0113
#define EC_DVD_AUDIO_STREAM_CHANGE 0x0104
#define EC_DVD_BUTTON_AUTO_ACTIVATED 0x0115
#define EC_DVD_BUTTON_CHANGE 0x0107
#define EC_DVD_CHAPTER_AUTOSTOP 0x010E
#define EC_DVD_CHAPTER_START 0x0103
#define EC_DVD_CMD_START 0x0116
#define EC_DVD_CMD_END 0x0117
#define EC_DVD_CURRENT_HMSF_TIME 0x011A
#define EC_DVD_CURRENT_TIME 0x010B
#define EC_DVD_DISC_EJECTED 0x0118
#define EC_DVD_DISC_INSERTED 0x0119
#define EC_DVD_DOMAIN_CHANGE 0x0101
#define EC_DVD_ERROR 0x010C
#define EC_DVD_KARAOKE_MODE 0x011B
#define EC_DVD_NO_FP_PGC 0x010F
#define EC_DVD_PARENTAL_LEVEL_CHANGE 0x0111
#define EC_DVD_PLAYBACK_RATE_CHANGE 0x0110
#define EC_DVD_PLAYBACK_STOPPED 0x0112
#define EC_DVD_PLAYPERIOD_AUTOSTOP 0x0114
#define EC_DVD_STILL_OFF 0x010A
#define EC_DVD_STILL_ON 0x0109
#define EC_DVD_SUBPICTURE_STREAM_CHANGE 0x0105
#define EC_DVD_TITLE_CHANGE 0x0102
#define EC_DVD_VALID_UOPS_CHANGE 0x0108
#define EC_DVD_WARNING 0x010D
typedef enum _tagDVD_ERROR {
	DVD_ERROR_Unexpected = 1,
	DVD_ERROR_CopyProtectFail = 2,   
	DVD_ERROR_InvalidDVD1_0Disc = 3,
	DVD_ERROR_InvalidDiscRegion = 4,
	DVD_ERROR_LowParentalLevel = 5,
	DVD_ERROR_MacrovisionFail = 6,
	DVD_ERROR_IncompatibleSystemAndDecoderRegions = 7,
	DVD_ERROR_IncompatibleDiscAndDecoderRegions = 8
} DVD_ERROR;
typedef enum _tagDVD_PB_STOPPED {
	DVD_PB_STOPPED_Other = 0,
	DVD_PB_STOPPED_NoBranch = 1,
	DVD_PB_STOPPED_NoFirstPlayDomain = 2,
	DVD_PB_STOPPED_StopCommand = 3,
	DVD_PB_STOPPED_Reset = 4,
	DVD_PB_STOPPED_DiscEjected = 5,
	DVD_PB_STOPPED_IllegalNavCommand = 6,
	DVD_PB_STOPPED_PlayPeriodAutoStop = 7,
	DVD_PB_STOPPED_PlayChapterAutoStop = 8,
	DVD_PB_STOPPED_ParentalFailure = 9,
	DVD_PB_STOPPED_RegionFailure = 10,
	DVD_PB_STOPPED_MacrovisionFailure = 11,
	DVD_PB_STOPPED_DiscReadError = 12,
	DVD_PB_STOPPED_CopyProtectFailure = 13
} DVD_PB_STOPPED;
typedef enum _tagDVD_WARNING {
	DVD_WARNING_InvalidDVD1_0Disc = 1,
	DVD_WARNING_FormatNotSupported = 2,
	DVD_WARNING_IllegalNavCommand = 3,
	DVD_WARNING_Open = 4,
	DVD_WARNING_Seek = 5,
	DVD_WARNING_Read = 6
} DVD_WARNING;

#ifdef __cplusplus
}
#endif
#endif
