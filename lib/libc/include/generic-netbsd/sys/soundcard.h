/*	$NetBSD: soundcard.h,v 1.34 2021/05/09 11:28:25 nia Exp $	*/

/*-
 * Copyright (c) 1997, 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Lennart Augustsson and Nia Alarie.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * WARNING!  WARNING!
 * This is an Open Sound System compatibility layer.
 * Use the Native NetBSD API in <sys/audioio.h> for developing new code,
 * and this only for compiling programs written for other operating systems.
 */

#ifndef _SOUNDCARD_H_
#define _SOUNDCARD_H_

#ifndef SOUND_VERSION
#define SOUND_VERSION 0x030001
#endif

#define	SNDCTL_DSP_RESET		_IO  ('P', 0)
#define	SNDCTL_DSP_SYNC			_IO  ('P', 1)
#define	SNDCTL_DSP_SPEED		_IOWR('P', 2, int)
#define	SOUND_PCM_READ_RATE		_IOR ('P', 2, int)
#define	SNDCTL_DSP_STEREO		_IOWR('P', 3, int)
#define	SNDCTL_DSP_GETBLKSIZE		_IOWR('P', 4, int)
#define	SNDCTL_DSP_SETFMT		_IOWR('P', 5, int)
#define	 AFMT_QUERY			0x00000000
#define	 AFMT_MU_LAW			0x00000001
#define	 AFMT_A_LAW			0x00000002
#define	 AFMT_IMA_ADPCM			0x00000004
#define	 AFMT_U8			0x00000008
#define	 AFMT_S16_LE			0x00000010
#define	 AFMT_S16_BE			0x00000020
#define	 AFMT_S8			0x00000040
#define	 AFMT_U16_LE			0x00000080
#define	 AFMT_U16_BE			0x00000100
#define	 AFMT_MPEG			0x00000200	/* Not supported */
#define	 AFMT_AC3			0x00000400
#define	 AFMT_S24_LE			0x00000800	/* Not supported */
#define	 AFMT_S24_BE			0x00001000	/* Not supported */
#define	 AFMT_S32_LE			0x00002000
#define	 AFMT_S32_BE			0x00004000
#define  AFMT_FLOAT			0x00010000	/* Not supported */
#define  AFMT_SPDIF_RAW			0x00020000	/* Not supported */
#define  AFMT_S24_PACKED		0x00040000	/* Not supported */
#define  AFMT_VORBIS			0x00080000	/* Not supported */
#define SNDCTL_DSP_SAMPLESIZE		SNDCTL_DSP_SETFMT
#define	SOUND_PCM_READ_BITS		_IOR ('P', 5, int)
#define	SNDCTL_DSP_CHANNELS		_IOWR('P', 6, int)
#define SOUND_PCM_WRITE_CHANNELS	SNDCTL_DSP_CHANNELS
#define	SOUND_PCM_READ_CHANNELS		_IOR ('P', 6, int)
#define SOUND_PCM_WRITE_FILTER		_IOWR('P', 7, int)
#define SOUND_PCM_READ_FILTER		_IOR ('P', 7, int)
#define	SNDCTL_DSP_POST			_IO  ('P', 8)
#define SNDCTL_DSP_SUBDIVIDE		_IOWR('P', 9, int)
#define	SNDCTL_DSP_SETFRAGMENT		_IOWR('P', 10, int)
#define	SNDCTL_DSP_GETFMTS		_IOR ('P', 11, int)
#define SNDCTL_DSP_GETOSPACE		_IOR ('P',12, struct audio_buf_info)
#define SNDCTL_DSP_GETISPACE		_IOR ('P',13, struct audio_buf_info)
#define SNDCTL_DSP_NONBLOCK		_IO  ('P',14)
#define SNDCTL_DSP_GETCAPS		_IOR ('P',15, int)
/* PCM_CAP_* were known as DSP_CAP_ before OSS 4.0 */
# define DSP_CAP_REVISION		PCM_CAP_REVISION
# define DSP_CAP_DUPLEX			PCM_CAP_DUPLEX
# define DSP_CAP_REALTIME		PCM_CAP_REALTIME
# define DSP_CAP_BATCH			PCM_CAP_BATCH
# define DSP_CAP_COPROC			PCM_CAP_COPROC
# define DSP_CAP_TRIGGER		PCM_CAP_TRIGGER
# define DSP_CAP_MMAP			PCM_CAP_MMAP
# define DSP_CAP_INPUT			PCM_CAP_INPUT
# define DSP_CAP_OUTPUT			PCM_CAP_OUTPUT
# define DSP_CAP_MODEM			PCM_CAP_MODEM
# define DSP_CAP_HIDDEN			PCM_CAP_HIDDEN
# define DSP_CAP_VIRTUAL		PCM_CAP_VIRTUAL
# define DSP_CAP_ANALOGOUT		PCM_CAP_ANALOGOUT
# define DSP_CAP_ANALOGIN		PCM_CAP_ANALOGIN
# define DSP_CAP_DIGITALOUT		PCM_CAP_DIGITALOUT
# define DSP_CAP_DIGITALIN		PCM_CAP_DIGITALIN
# define DSP_CAP_ADMASK			PCM_CAP_ADMASK
# define DSP_CAP_FREERATE		PCM_CAP_FREERATE
# define DSP_CAP_MULTI			PCM_CAP_MULTI
# define DSP_CAP_BIND			PCM_CAP_BIND
# define DSP_CAP_SHADOW			PCM_CAP_SHADOW
# define PCM_CAP_REVISION		0x000000ff	/* Unused in NetBSD */
# define PCM_CAP_DUPLEX			0x00000100	/* Full duplex */
# define PCM_CAP_REALTIME		0x00000200	/* Unused in NetBSD */
# define PCM_CAP_BATCH			0x00000400	/* Unused in NetBSD */
# define PCM_CAP_COPROC			0x00000800	/* Unused in NetBSD */
# define PCM_CAP_TRIGGER		0x00001000	/* Supports SETTRIGGER */
# define PCM_CAP_MMAP			0x00002000	/* Supports mmap() */
# define PCM_CAP_INPUT			0x00004000	/* Recording device */
# define PCM_CAP_OUTPUT			0x00008000	/* Playback device */
# define PCM_CAP_MODEM			0x00010000	/* Unused in NetBSD */
# define PCM_CAP_HIDDEN			0x00020000	/* Unused in NetBSD */
# define PCM_CAP_VIRTUAL		0x00040000	/* Unused in NetBSD */
# define PCM_CAP_MULTI			0x00080000	/* Simultaneous open() */
# define PCM_CAP_ANALOGOUT		0x00100000	/* Unused in NetBSD */
# define PCM_CAP_ANALOGIN		0x00200000	/* Unused in NetBSD */
# define PCM_CAP_DIGITALOUT		0x00400000	/* Unused in NetBSD */
# define PCM_CAP_DIGITALIN		0x00800000	/* Unused in NetBSD */
# define PCM_CAP_ADMASK			0x00f00000	/* Unused in NetBSD */
# define PCM_CAP_SPECIAL		0x01000000	/* Unused in NetBSD */
# define PCM_CAP_FREERATE		0x10000000	/* Freely set rate */
# define PCM_CAP_SHADOW			0x40000000	/* Unused in NetBSD */
# define PCM_CAP_BIND			0x80000000	/* Unused in NetBSD */
# define DSP_CH_ANY			0x00000000	/* No preferred mode */
# define DSP_CH_MONO			0x02000000
# define DSP_CH_STEREO			0x04000000
# define DSP_CH_MULTI			0x06000000
# define DSP_CH_MASK			0x06000000
#define SNDCTL_DSP_GETTRIGGER		_IOR ('P', 16, int)
#define SNDCTL_DSP_SETTRIGGER		_IOW ('P', 16, int)
# define PCM_ENABLE_INPUT		0x00000001
# define PCM_ENABLE_OUTPUT		0x00000002
#define SNDCTL_DSP_GETIPTR		_IOR ('P', 17, struct count_info)
#define SNDCTL_DSP_GETOPTR		_IOR ('P', 18, struct count_info)
#define SNDCTL_DSP_MAPINBUF		_IOR ('P', 19, struct buffmem_desc)
#define SNDCTL_DSP_MAPOUTBUF		_IOR ('P', 20, struct buffmem_desc)
#define SNDCTL_DSP_SETSYNCRO		_IO  ('P', 21)
#define SNDCTL_DSP_SETDUPLEX		_IO  ('P', 22)
#define SNDCTL_DSP_PROFILE		_IOW ('P', 23, int)
#define SNDCTL_DSP_GETODELAY		_IOR ('P', 23, int)
#define	  APF_NORMAL			0
#define	  APF_NETWORK			1
#define   APF_CPUINTENS			2

/* Need native 16 bit format which depends on byte order */
#include <machine/endian_machdep.h>
#if _BYTE_ORDER == _LITTLE_ENDIAN
#define  AFMT_U16_NE AFMT_U16_LE
#define  AFMT_U16_OE AFMT_U16_BE
#define  AFMT_S16_NE AFMT_S16_LE
#define  AFMT_S16_OE AFMT_S16_BE
#define  AFMT_S24_NE AFMT_S24_LE
#define  AFMT_S24_OE AFMT_S24_BE
#define  AFMT_S32_NE AFMT_S32_LE
#define  AFMT_S32_OE AFMT_S32_BE
#else
#define  AFMT_U16_NE AFMT_U16_BE
#define  AFMT_U16_OE AFMT_U16_LE
#define  AFMT_S16_NE AFMT_S16_BE
#define  AFMT_S16_OE AFMT_S16_LE
#define  AFMT_S24_NE AFMT_S24_BE
#define  AFMT_S24_OE AFMT_S24_LE
#define  AFMT_S32_NE AFMT_S32_BE
#define  AFMT_S32_OE AFMT_S32_LE
#endif

/* Aliases */
#define SOUND_PCM_WRITE_BITS		SNDCTL_DSP_SETFMT
#define SOUND_PCM_WRITE_RATE		SNDCTL_DSP_SPEED
#define SOUND_PCM_POST			SNDCTL_DSP_POST
#define SOUND_PCM_RESET			SNDCTL_DSP_RESET
#define SOUND_PCM_SYNC			SNDCTL_DSP_SYNC
#define SOUND_PCM_SUBDIVIDE		SNDCTL_DSP_SUBDIVIDE
#define SOUND_PCM_SETFRAGMENT		SNDCTL_DSP_SETFRAGMENT
#define SOUND_PCM_GETFMTS		SNDCTL_DSP_GETFMTS
#define SOUND_PCM_SETFMT		SNDCTL_DSP_SETFMT
#define SOUND_PCM_GETOSPACE		SNDCTL_DSP_GETOSPACE
#define SOUND_PCM_GETISPACE		SNDCTL_DSP_GETISPACE
#define SOUND_PCM_NONBLOCK		SNDCTL_DSP_NONBLOCK
#define SOUND_PCM_GETCAPS		SNDCTL_DSP_GETCAPS
#define SOUND_PCM_GETTRIGGER		SNDCTL_DSP_GETTRIGGER
#define SOUND_PCM_SETTRIGGER		SNDCTL_DSP_SETTRIGGER
#define SOUND_PCM_SETSYNCRO		SNDCTL_DSP_SETSYNCRO
#define SOUND_PCM_GETIPTR		SNDCTL_DSP_GETIPTR
#define SOUND_PCM_GETOPTR		SNDCTL_DSP_GETOPTR
#define SOUND_PCM_MAPINBUF		SNDCTL_DSP_MAPINBUF
#define SOUND_PCM_MAPOUTBUF		SNDCTL_DSP_MAPOUTBUF

/* Mixer defines */
#define SOUND_MIXER_FIRST		0
#define SOUND_MIXER_NRDEVICES		25

#define SOUND_MIXER_VOLUME		0
#define SOUND_MIXER_BASS		1
#define SOUND_MIXER_TREBLE		2
#define SOUND_MIXER_SYNTH		3
#define SOUND_MIXER_PCM			4
#define SOUND_MIXER_SPEAKER		5
#define SOUND_MIXER_LINE		6
#define SOUND_MIXER_MIC			7
#define SOUND_MIXER_CD			8
#define SOUND_MIXER_IMIX		9
#define SOUND_MIXER_ALTPCM		10
#define SOUND_MIXER_RECLEV		11
#define SOUND_MIXER_IGAIN		12
#define SOUND_MIXER_OGAIN		13
#define SOUND_MIXER_LINE1		14
#define SOUND_MIXER_LINE2		15
#define SOUND_MIXER_LINE3		16
#define SOUND_MIXER_DIGITAL1		17
#define SOUND_MIXER_DIGITAL2		18
#define SOUND_MIXER_DIGITAL3		19
#define SOUND_MIXER_PHONEIN		20
#define SOUND_MIXER_PHONEOUT		21
#define SOUND_MIXER_VIDEO		22
#define SOUND_MIXER_RADIO		23
#define SOUND_MIXER_MONITOR		24

#define SOUND_ONOFF_MIN			28
#define SOUND_ONOFF_MAX			30

#define SOUND_MIXER_NONE		31

#define SOUND_DEVICE_LABELS	{"Vol  ", "Bass ", "Trebl", "Synth", "Pcm  ", "Spkr ", "Line ", \
				 "Mic  ", "CD   ", "Mix  ", "Pcm2 ", "Rec  ", "IGain", "OGain", \
				 "Line1", "Line2", "Line3", "Digital1", "Digital2", "Digital3", \
				 "PhoneIn", "PhoneOut", "Video", "Radio", "Monitor"}

#define SOUND_DEVICE_NAMES	{"vol", "bass", "treble", "synth", "pcm", "speaker", "line", \
				 "mic", "cd", "mix", "pcm2", "rec", "igain", "ogain", \
				 "line1", "line2", "line3", "dig1", "dig2", "dig3", \
				 "phin", "phout", "video", "radio", "monitor"}

#define SOUND_MIXER_RECSRC		0xff
#define SOUND_MIXER_DEVMASK		0xfe
#define SOUND_MIXER_RECMASK		0xfd
#define SOUND_MIXER_CAPS		0xfc
#define  SOUND_CAP_EXCL_INPUT		1
#define SOUND_MIXER_STEREODEVS		0xfb

#define MIXER_READ(dev)			_IOR('M', dev, int)

#define SOUND_MIXER_READ_RECSRC		MIXER_READ(SOUND_MIXER_RECSRC)
#define SOUND_MIXER_READ_DEVMASK	MIXER_READ(SOUND_MIXER_DEVMASK)
#define SOUND_MIXER_READ_RECMASK	MIXER_READ(SOUND_MIXER_RECMASK)
#define SOUND_MIXER_READ_STEREODEVS	MIXER_READ(SOUND_MIXER_STEREODEVS)
#define SOUND_MIXER_READ_CAPS		MIXER_READ(SOUND_MIXER_CAPS)

#define SOUND_MIXER_READ_VOLUME		MIXER_READ(SOUND_MIXER_VOLUME)
#define SOUND_MIXER_READ_BASS		MIXER_READ(SOUND_MIXER_BASS)
#define SOUND_MIXER_READ_TREBLE		MIXER_READ(SOUND_MIXER_TREBLE)
#define SOUND_MIXER_READ_SYNTH		MIXER_READ(SOUND_MIXER_SYNTH)
#define SOUND_MIXER_READ_PCM		MIXER_READ(SOUND_MIXER_PCM)
#define SOUND_MIXER_READ_SPEAKER	MIXER_READ(SOUND_MIXER_SPEAKER)
#define SOUND_MIXER_READ_LINE		MIXER_READ(SOUND_MIXER_LINE)
#define SOUND_MIXER_READ_MIC		MIXER_READ(SOUND_MIXER_MIC)
#define SOUND_MIXER_READ_CD		MIXER_READ(SOUND_MIXER_CD)
#define SOUND_MIXER_READ_IMIX		MIXER_READ(SOUND_MIXER_IMIX)
#define SOUND_MIXER_READ_ALTPCM		MIXER_READ(SOUND_MIXER_ALTPCM)
#define SOUND_MIXER_READ_RECLEV		MIXER_READ(SOUND_MIXER_RECLEV)
#define SOUND_MIXER_READ_IGAIN		MIXER_READ(SOUND_MIXER_IGAIN)
#define SOUND_MIXER_READ_OGAIN		MIXER_READ(SOUND_MIXER_OGAIN)
#define SOUND_MIXER_READ_LINE1		MIXER_READ(SOUND_MIXER_LINE1)
#define SOUND_MIXER_READ_LINE2		MIXER_READ(SOUND_MIXER_LINE2)
#define SOUND_MIXER_READ_LINE3		MIXER_READ(SOUND_MIXER_LINE3)

#define MIXER_WRITE(dev)		_IOW ('M', dev, int)
#define MIXER_WRITE_R(dev)		_IOWR('M', dev, int)

#define SOUND_MIXER_WRITE_RECSRC	MIXER_WRITE(SOUND_MIXER_RECSRC)
#define SOUND_MIXER_WRITE_R_RECSRC	MIXER_WRITE_R(SOUND_MIXER_RECSRC)

#define SOUND_MIXER_WRITE_VOLUME	MIXER_WRITE(SOUND_MIXER_VOLUME)
#define SOUND_MIXER_WRITE_BASS		MIXER_WRITE(SOUND_MIXER_BASS)
#define SOUND_MIXER_WRITE_TREBLE	MIXER_WRITE(SOUND_MIXER_TREBLE)
#define SOUND_MIXER_WRITE_SYNTH		MIXER_WRITE(SOUND_MIXER_SYNTH)
#define SOUND_MIXER_WRITE_PCM		MIXER_WRITE(SOUND_MIXER_PCM)
#define SOUND_MIXER_WRITE_SPEAKER	MIXER_WRITE(SOUND_MIXER_SPEAKER)
#define SOUND_MIXER_WRITE_LINE		MIXER_WRITE(SOUND_MIXER_LINE)
#define SOUND_MIXER_WRITE_MIC		MIXER_WRITE(SOUND_MIXER_MIC)
#define SOUND_MIXER_WRITE_CD		MIXER_WRITE(SOUND_MIXER_CD)
#define SOUND_MIXER_WRITE_IMIX		MIXER_WRITE(SOUND_MIXER_IMIX)
#define SOUND_MIXER_WRITE_ALTPCM	MIXER_WRITE(SOUND_MIXER_ALTPCM)
#define SOUND_MIXER_WRITE_RECLEV	MIXER_WRITE(SOUND_MIXER_RECLEV)
#define SOUND_MIXER_WRITE_IGAIN		MIXER_WRITE(SOUND_MIXER_IGAIN)
#define SOUND_MIXER_WRITE_OGAIN		MIXER_WRITE(SOUND_MIXER_OGAIN)
#define SOUND_MIXER_WRITE_LINE1		MIXER_WRITE(SOUND_MIXER_LINE1)
#define SOUND_MIXER_WRITE_LINE2		MIXER_WRITE(SOUND_MIXER_LINE2)
#define SOUND_MIXER_WRITE_LINE3		MIXER_WRITE(SOUND_MIXER_LINE3)

#define SOUND_MASK_VOLUME	(1 << SOUND_MIXER_VOLUME)
#define SOUND_MASK_BASS		(1 << SOUND_MIXER_BASS)
#define SOUND_MASK_TREBLE	(1 << SOUND_MIXER_TREBLE)
#define SOUND_MASK_SYNTH	(1 << SOUND_MIXER_SYNTH)
#define SOUND_MASK_PCM		(1 << SOUND_MIXER_PCM)
#define SOUND_MASK_SPEAKER	(1 << SOUND_MIXER_SPEAKER)
#define SOUND_MASK_LINE		(1 << SOUND_MIXER_LINE)
#define SOUND_MASK_MIC		(1 << SOUND_MIXER_MIC)
#define SOUND_MASK_CD		(1 << SOUND_MIXER_CD)
#define SOUND_MASK_IMIX		(1 << SOUND_MIXER_IMIX)
#define SOUND_MASK_ALTPCM	(1 << SOUND_MIXER_ALTPCM)
#define SOUND_MASK_RECLEV	(1 << SOUND_MIXER_RECLEV)
#define SOUND_MASK_IGAIN	(1 << SOUND_MIXER_IGAIN)
#define SOUND_MASK_OGAIN	(1 << SOUND_MIXER_OGAIN)
#define SOUND_MASK_LINE1	(1 << SOUND_MIXER_LINE1)
#define SOUND_MASK_LINE2	(1 << SOUND_MIXER_LINE2)
#define SOUND_MASK_LINE3	(1 << SOUND_MIXER_LINE3)
#define SOUND_MASK_DIGITAL1	(1 << SOUND_MIXER_DIGITAL1)
#define SOUND_MASK_DIGITAL2	(1 << SOUND_MIXER_DIGITAL2)
#define SOUND_MASK_DIGITAL3	(1 << SOUND_MIXER_DIGITAL3)
#define SOUND_MASK_PHONEIN	(1 << SOUND_MIXER_PHONEIN)
#define SOUND_MASK_PHONEOUT	(1 << SOUND_MIXER_PHONEOUT)
#define SOUND_MASK_VIDEO	(1 << SOUND_MIXER_VIDEO)
#define SOUND_MASK_RADIO	(1 << SOUND_MIXER_RADIO)
#define SOUND_MASK_MONITOR	(1 << SOUND_MIXER_MONITOR)

typedef struct mixer_info {
	char id[16];
	char name[32];
	int  modify_counter;
	int  fillers[10];
} mixer_info;

typedef struct _old_mixer_info {
	char id[16];
	char name[32];
} _old_mixer_info;

#define SOUND_MIXER_INFO		_IOR('M', 101, mixer_info)
#define SOUND_OLD_MIXER_INFO		_IOR('M', 101, _old_mixer_info)

#define OSS_GETVERSION			_IOR ('M', 118, int)

typedef struct audio_buf_info {
	int fragments;
	int fragstotal;
	int fragsize;
	int bytes;
} audio_buf_info;

typedef struct count_info {
	int bytes;
	int blocks;
	int ptr;
} count_info;

typedef struct buffmem_desc {
	unsigned int *buffer;
	int size;
} buffmem_desc;

/* Some OSSv4 calls. */

/* Why is yet more duplication necessary? Sigh. */
#define OSS_OPEN_READ		PCM_ENABLE_INPUT
#define OSS_OPEN_WRITE		PCM_ENABLE_OUTPUT
#define OSS_OPEN_READWRITE	(OSS_OPEN_READ|OSS_OPEN_WRITE)

#define OSS_DEVNODE_SIZE		32
#define OSS_LABEL_SIZE			16
#define OSS_LONGNAME_SIZE		64
#define OSS_MAX_AUDIO_DEVS		64

#define SNDCTL_DSP_GETPLAYVOL		_IOR ('P',27, uint)
#define SNDCTL_DSP_SETPLAYVOL		_IOW ('P',28, uint)
#define SNDCTL_DSP_GETRECVOL		_IOR ('P',29, uint)
#define SNDCTL_DSP_SETRECVOL		_IOW ('P',30, uint)
#define SNDCTL_DSP_SKIP			_IO ('P',31)
#define SNDCTL_DSP_SILENCE		_IO ('P',32)
#define SNDCTL_DSP_COOKEDMODE		_IOW ('P',33, int)
#define SNDCTL_DSP_GETERROR		_IOR ('P',34, struct audio_errinfo)
#define SNDCTL_DSP_CURRENT_IPTR		_IOR ('P',35, oss_count_t)
#define SNDCTL_DSP_CURRENT_OPTR		_IOR ('P',36, oss_count_t)
#define SNDCTL_DSP_GET_RECSRC_NAMES	_IOR ('P',37, oss_mixer_enuminfo)
#define SNDCTL_DSP_GET_RECSRC		_IOR ('P',38, int)
#define SNDCTL_DSP_SET_RECSRC		_IOWR ('P',38, int)
#define SNDCTL_DSP_GET_PLAYTGT_NAMES	_IOR ('P',39, oss_mixer_enuminfo)
#define SNDCTL_DSP_GET_PLAYTGT		_IOR ('P',40, int)
#define SNDCTL_DSP_SET_PLAYTGT		_IOWR ('P',40, int)

#define SNDCTL_DSP_GET_CHNORDER		_IOR ('P',42, unsigned long long)
#define SNDCTL_DSP_SET_CHNORDER		_IOWR ('P',42, unsigned long long)

#define SNDCTL_DSP_HALT_OUTPUT		_IO ('P',70)
#define SNDCTL_DSP_RESET_OUTPUT		SNDCTL_DSP_HALT_OUTPUT	/* Old name */
#define SNDCTL_DSP_HALT_INPUT		_IO ('P',71)
#define SNDCTL_DSP_RESET_INPUT		SNDCTL_DSP_HALT_INPUT	/* Old name */

#define CHID_UNDEF	0
#define CHID_L		1
#define CHID_R		2
#define CHID_C		3
#define CHID_LFE	4
#define CHID_LS		5
#define CHID_RS		6
#define CHID_LR		7
#define CHID_RR		8
#define CHNORDER_UNDEF	0x0000000000000000ULL
#define CHNORDER_NORMAL	0x0000000087654321ULL

typedef struct {
	long long samples;
	int fifo_samples;
	int filler[32];			/* "Future use" */
} oss_count_t;

typedef struct audio_errinfo {
	int play_underruns;
	int rec_overruns;
	unsigned int play_ptradjust;	/* Obsolete */
	unsigned int rec_ptradjust;	/* Obsolete */
	int play_errorcount;		/* Unused */
	int rec_errorcount;		/* Unused */
	int play_lasterror;		/* Unused */
	int rec_lasterror;		/* Unused */
	int play_errorparm;		/* Unused */
	int rec_errorparm;		/* Unused */
	int filler[16];			/* Unused */
} audio_errinfo;

typedef struct oss_sysinfo {
	char product[32];
	char version[32];
	int versionnum;
	char options[128];		/* Future use */
	int numaudios;
	int openedaudio[8];		/* Obsolete */
	int numsynths;			/* Obsolete */
	int nummidis;
	int numtimers;
	int nummixers;
	int openedmidi[8];
	int numcards;
	int numaudioengines;
	char license[16];
	char revision_info[256];	/* Internal Use */
	int filler[172];		/* For expansion */
} oss_sysinfo;

typedef struct oss_audioinfo {
	int dev;		/* Set by caller */
	char name[OSS_LONGNAME_SIZE];
	int busy;
	int pid;
	int caps;
	int iformats;
	int oformats;
	int magic;		/* Unused */
	char cmd[OSS_LONGNAME_SIZE];
	int card_number;
	int port_number;
	int mixer_dev;
	int legacy_device;	/* Obsolete */
	int enabled;
	int flags;		/* Reserved */
	int min_rate;
	int max_rate;
	int min_channels;
	int max_channels;
	int binding;		/* Reserved */
	int rate_source;
	char handle[32];
#define OSS_MAX_SAMPLE_RATES	20
	int nrates;
	int rates[OSS_MAX_SAMPLE_RATES];
	char song_name[OSS_LONGNAME_SIZE];
	char label[OSS_LABEL_SIZE];
	int latency;				/* In usecs -1 = unknown */
	char devnode[OSS_DEVNODE_SIZE];	
	int next_play_engine;
	int next_rec_engine;
	int filler[184];			/* For expansion */
} oss_audioinfo;

typedef struct oss_card_info {
	int card;
	char shortname[16];
	char longname[128];
	int flags;
	char hw_info[400];
	int intr_count;
	int ack_count;
	int filler[154];
} oss_card_info;

#define SNDCTL_SYSINFO		_IOR ('X', 1, oss_sysinfo)
#define OSS_SYSINFO		SNDCTL_SYSINFO /* Old name */
#define SNDCTL_MIX_NRMIX	_IOR ('X',2, int)
#define SNDCTL_MIX_NREXT	_IOWR ('X',3, int)
#define SNDCTL_MIX_EXTINFO	_IOWR ('X',4, oss_mixext)
#define SNDCTL_MIX_READ		_IOWR ('X',5, oss_mixer_value)
#define SNDCTL_MIX_WRITE	_IOWR ('X',6, oss_mixer_value)
#define SNDCTL_AUDIOINFO	_IOWR ('X',7, oss_audioinfo)
#define SNDCTL_MIX_ENUMINFO	_IOWR ('X',8, oss_mixer_enuminfo)
#define SNDCTL_MIXERINFO	_IOWR ('X',10, oss_mixerinfo)
#define SNDCTL_CARDINFO		_IOWR ('X',11, oss_card_info)
#define SNDCTL_ENGINEINFO	_IOWR ('X',12, oss_audioinfo)
#define SNDCTL_AUDIOINFO_EX	_IOWR ('X',13, oss_audioinfo)
#define SNDCTL_MIX_DESCRIPTION	_IOWR ('X',14, oss_mixer_enuminfo)

#define MIXT_DEVROOT	 	0 /* Used for default classes */
#define MIXT_GROUP	 	1 /* Used for classes */
#define MIXT_ONOFF	 	2 /* Used for mute controls */
#define MIXT_ENUM	 	3 /* Used for enum controls */
#define MIXT_MONOSLIDER	 	4 /* Used for mono and surround controls */
#define MIXT_STEREOSLIDER 	5 /* Used for stereo controls */
#define MIXT_MESSAGE	 	6 /* OSS compat, unused on NetBSD */
#define MIXT_MONOVU	 	7 /* OSS compat, unused on NetBSD */
#define MIXT_STEREOVU	 	8 /* OSS compat, unused on NetBSD */
#define MIXT_MONOPEAK	 	9 /* OSS compat, unused on NetBSD */
#define MIXT_STEREOPEAK		10 /* OSS compat, unused on NetBSD */
#define MIXT_RADIOGROUP		11 /* OSS compat, unused on NetBSD */
#define MIXT_MARKER		12 /* OSS compat, unused on NetBSD */
#define MIXT_VALUE		13 /* OSS compat, unused on NetBSD */
#define MIXT_HEXVALUE		14 /* OSS compat, unused on NetBSD */
#define MIXT_MONODB		15 /* OSS compat, unused on NetBSD */
#define MIXT_STEREODB		16 /* OSS compat, unused on NetBSD */
#define MIXT_SLIDER		17 /* OSS compat, unused on NetBSD */
#define MIXT_3D			18 /* OSS compat, unused on NetBSD */
#define MIXT_MONOSLIDER16	19 /* OSS compat, unused on NetBSD */
#define MIXT_STEREOSLIDER16	20 /* OSS compat, unused on NetBSD */
#define MIXT_MUTE		21 /* OSS compat, unused on NetBSD */
/*
 * Should be used for Set controls. 
 * In practice nothing uses this because it's "reserved for Sun's
 * implementation".
 */
#define MIXT_ENUM_MULTI		22

#define MIXF_READABLE	0x00000001 /* Value is readable: always true */
#define MIXF_WRITEABLE	0x00000002 /* Value is writable: always true */
#define MIXF_POLL	0x00000004 /* Can change between reads: always true */
#define MIXF_HZ		0x00000008 /* OSS compat, unused on NetBSD */
#define MIXF_STRING	0x00000010 /* OSS compat, unused on NetBSD */
#define MIXF_DYNAMIC	0x00000010 /* OSS compat, unused on NetBSD */
#define MIXF_OKFAIL	0x00000020 /* OSS compat, unused on NetBSD */
#define MIXF_FLAT	0x00000040 /* OSS compat, unused on NetBSD */
#define MIXF_LEGACY	0x00000080 /* OSS compat, unused on NetBSD */
#define MIXF_CENTIBEL	0x00000100 /* OSS compat, unused on NetBSD */
#define MIXF_DECIBEL	0x00000200 /* OSS compat, unused on NetBSD */
#define MIXF_MAINVOL	0x00000400 /* OSS compat, unused on NetBSD */
#define MIXF_PCMVOL	0x00000800 /* OSS compat, unused on NetBSD */
#define MIXF_RECVOL	0x00001000 /* OSS compat, unused on NetBSD */
#define MIXF_MONVOL	0x00002000 /* OSS compat, unused on NetBSD */
#define MIXF_WIDE	0x00004000 /* OSS compat, unused on NetBSD */
#define MIXF_DESCR	0x00008000 /* OSS compat, unused on NetBSD */
#define MIXF_DISABLED	0x00010000 /* OSS compat, unused on NetBSD */

/* None of the mixer capabilities are set on NetBSD. */
#define MIXER_CAP_VIRTUAL	0x00000001	/* Virtual device */
#define MIXER_CAP_LAYOUT_B	0x00000002	/* "Internal use only" */
#define MIXER_CAP_NARROW	0x00000004	/* "Conserve screen space" */

#define OSS_ID_SIZE		16
typedef char oss_id_t[OSS_ID_SIZE];
#define OSS_DEVNODE_SIZE	32
typedef char oss_devnode_t[OSS_DEVNODE_SIZE];
#define OSS_HANDLE_SIZE		32
typedef char oss_handle_t[OSS_HANDLE_SIZE];
#define	OSS_LONGNAME_SIZE	64
typedef char oss_longname_t[OSS_LONGNAME_SIZE];
#define	OSS_LABEL_SIZE		16
typedef char oss_label_t[OSS_LABEL_SIZE];

typedef struct oss_mixext_root {
	oss_id_t id;
	char name[48];
} oss_mixext_root;

typedef struct oss_mixerinfo {
	int dev;
	oss_id_t id;
	char name[32];	
	int modify_counter;
	int card_number;
	int port_number;
	oss_handle_t handle;
	int magic;		/* "Reserved for internal use" */
	int enabled;
	int caps;
	int flags;		/* "Reserved for internal use" */
	int nrext;
	int priority;
	oss_devnode_t devnode;
	int legacy_device;
	int filler[245];
} oss_mixerinfo;

typedef struct oss_mixer_value {
	int dev;	/* Set by caller */
	int ctrl;	/* Set by caller */
	int value;
	int flags;	/* Reserved for "future use" */
	int timestamp;
	int filler[8];	/* Reserved for "future use" */
} oss_mixer_value;

#define OSS_ENUM_MAXVALUE	255
#define OSS_ENUM_STRINGSIZE	3000

typedef struct oss_mixer_enuminfo {
	int dev;	/* Set by caller */
	int ctrl;	/* Set by caller */
	int nvalues;
	int version;
	short strindex[OSS_ENUM_MAXVALUE];
	char strings[OSS_ENUM_STRINGSIZE];
} oss_mixer_enuminfo;

typedef struct oss_mixext {
	int dev;
	int ctrl;
	int type;
	int maxvalue;
	int minvalue;
	int flags;
	oss_id_t id;
	int parent;
	int dummy;
	int timestamp;
	char data[64];
	unsigned char enum_present[32];
	int control_no;
	unsigned int desc;
	char extname[32];
	int update_counter;
	int rgbcolor;
	int filler[6];
} oss_mixext;


/*
 * These are no-ops on FreeBSD, NetBSD, and Solaris,
 * but are defined for compatibility with OSSv4.
 */
#define SNDCTL_SETSONG		_IOW ('Y',2, oss_longname_t)
#define SNDCTL_GETSONG		_IOR ('Y',2, oss_longname_t)
#define SNDCTL_SETNAME		_IOW ('Y',3, oss_longname_t)
#define SNDCTL_SETLABEL		_IOW ('Y',4, oss_label_t)
#define SNDCTL_GETLABEL		_IOR ('Y',4, oss_label_t)

#define ioctl _oss_ioctl
/*
 * If we already included <sys/ioctl.h>, then we define our own prototype,
 * else we depend on <sys/ioctl.h> to do it for us. We do it this way, so
 * that we don't define the prototype twice.
 */
#ifndef _SYS_IOCTL_H_
#include <sys/ioctl.h>
#else
__BEGIN_DECLS
int _oss_ioctl(int, unsigned long, ...);
__END_DECLS
#endif

#endif /* !_SOUNDCARD_H_ */