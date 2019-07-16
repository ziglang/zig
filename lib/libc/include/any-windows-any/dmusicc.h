#undef INTERFACE
/* DirectMusic Core API Stuff
 *
 * Copyright (C) 2003-2004 Rok Mandeljc
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __WINE_DMUSIC_CORE_H
#define __WINE_DMUSIC_CORE_H

#include <windows.h>

#define COM_NO_WINDOWS_H
#include <objbase.h>
#include <mmsystem.h>

#include <dls1.h>
#include <dmerror.h>
#include <dmdls.h>
#include <dsound.h>
#include <dmusbuff.h>

#include <pshpack8.h>

#ifdef __cplusplus
extern "C" {
#endif


/*****************************************************************************
 * Predeclare the interfaces
 */
/* CLSIDs */
DEFINE_GUID(CLSID_DirectMusic,                    0x636b9f10,0x0c7d,0x11d1,0x95,0xb2,0x00,0x20,0xaf,0xdc,0x74,0x21);
DEFINE_GUID(CLSID_DirectMusicCollection,          0x480ff4b0,0x28b2,0x11d1,0xbe,0xf7,0x00,0xc0,0x4f,0xbf,0x8f,0xef);
DEFINE_GUID(CLSID_DirectMusicSynth,               0x58c2b4d0,0x46e7,0x11d1,0x89,0xac,0x00,0xa0,0xc9,0x05,0x41,0x29);
	
/* IIDs */
DEFINE_GUID(IID_IDirectMusic,                     0x6536115a,0x7b2d,0x11d2,0xba,0x18,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(IID_IDirectMusic2,                    0x6fc2cae1,0xbc78,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(IID_IDirectMusic8,                    0x2d3629f7,0x813d,0x4939,0x85,0x08,0xf0,0x5c,0x6b,0x75,0xfd,0x97);
DEFINE_GUID(IID_IDirectMusicBuffer,               0xd2ac2878,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicCollection,           0xd2ac287c,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicDownload,             0xd2ac287b,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicDownloadedInstrument, 0xd2ac287e,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicInstrument,           0xd2ac287d,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicPort,                 0x08f2d8c9,0x37c2,0x11d2,0xb9,0xf9,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(IID_IDirectMusicPortDownload,         0xd2ac287a,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicThru,                 0xced153e7,0x3606,0x11d2,0xb9,0xf9,0x00,0x00,0xf8,0x75,0xac,0x12);

#define IID_IDirectMusicCollection8 IID_IDirectMusicCollection
#define IID_IDirectMusicDownload8 IID_IDirectMusicDownload
#define IID_IDirectMusicDownloadedInstrument8 IID_IDirectMusicDownloadedInstrument
#define IID_IDirectMusicInstrument8 IID_IDirectMusicInstrument
#define IID_IDirectMusicPort8 IID_IDirectMusicPort
#define IID_IDirectMusicPortDownload8 IID_IDirectMusicPortDownload
#define IID_IDirectMusicThru8 IID_IDirectMusicThru

/* GUIDs - property set */
DEFINE_GUID(GUID_DMUS_PROP_GM_Hardware,           0x178f2f24,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(GUID_DMUS_PROP_GS_Capable,            0x6496aba2,0x61b0,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(GUID_DMUS_PROP_GS_Hardware,           0x178f2f25,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(GUID_DMUS_PROP_DLS1,                  0x178f2f27,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(GUID_DMUS_PROP_DLS2,                  0xf14599e5,0x4689,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(GUID_DMUS_PROP_Effects,               0xcda8d611,0x684a,0x11d2,0x87,0x1e,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_DMUS_PROP_INSTRUMENT2,           0x865fd372,0x9f67,0x11d2,0x87,0x2a,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_DMUS_PROP_LegacyCaps,            0xcfa7cdc2,0x00a1,0x11d2,0xaa,0xd5,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(GUID_DMUS_PROP_MemorySize,            0x178f2f28,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(GUID_DMUS_PROP_SampleMemorySize,      0x178f2f28,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(GUID_DMUS_PROP_SamplePlaybackRate,    0x2a91f713,0xa4bf,0x11d2,0xbb,0xdf,0x00,0x60,0x08,0x33,0xdb,0xd8);
DEFINE_GUID(GUID_DMUS_PROP_SynthSink_DSOUND,      0x0aa97844,0xc877,0x11d1,0x87,0x0c,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_DMUS_PROP_SynthSink_WAVE,        0x0aa97845,0xc877,0x11d1,0x87,0x0c,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_DMUS_PROP_Volume,                0xfedfae25,0xe46e,0x11d1,0xaa,0xce,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(GUID_DMUS_PROP_WavesReverb,           0x04cb5622,0x32e5,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(GUID_DMUS_PROP_WriteLatency,          0x268a0fa0,0x60f2,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(GUID_DMUS_PROP_WritePeriod,           0x268a0fa1,0x60f2,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(GUID_DMUS_PROP_XG_Capable,            0x6496aba1,0x61b0,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(GUID_DMUS_PROP_XG_Hardware,           0x178f2f26,0xc364,0x11d1,0xa7,0x60,0x00,0x00,0xf8,0x75,0xac,0x12);	

/* typedef definitions */
typedef struct IDirectMusic *LPDIRECTMUSIC;
typedef struct IDirectMusic8 *LPDIRECTMUSIC8;
typedef struct IDirectMusicBuffer *LPDIRECTMUSICBUFFER;
typedef struct IDirectMusicBuffer IDirectMusicBuffer8, *LPDIRECTMUSICBUFFER8;
typedef struct IDirectMusicInstrument *LPDIRECTMUSICINSTRUMENT;
typedef struct IDirectMusicInstrument IDirectMusicInstrument8, *LPDIRECTMUSICINSTRUMENT8;
typedef struct IDirectMusicDownloadedInstrument *LPDIRECTMUSICDOWNLOADEDINSTRUMENT;
typedef struct IDirectMusicDownloadedInstrument IDirectMusicDownloadedInstrument8, *LPDIRECTMUSICDOWNLOADEDINSTRUMENT8;
typedef struct IDirectMusicCollection *LPDIRECTMUSICCOLLECTION;
typedef struct IDirectMusicCollection IDirectMusicCollection8, *LPDIRECTMUSICCOLLECTION8;
typedef struct IDirectMusicDownload *LPDIRECTMUSICDOWNLOAD;
typedef struct IDirectMusicDownload IDirectMusicDownload8, *LPDIRECTMUSICDOWNLOAD8;
typedef struct IDirectMusicPortDownload *LPDIRECTMUSICPORTDOWNLOAD;
typedef struct IDirectMusicPortDownload IDirectMusicPortDownload8, *LPDIRECTMUSICPORTDOWNLOAD8;
typedef struct IDirectMusicPort *LPDIRECTMUSICPORT;
typedef struct IDirectMusicPort IDirectMusicPort8, *LPDIRECTMUSICPORT8;
typedef struct IDirectMusicThru *LPDIRECTMUSICTHRU;
typedef struct IDirectMusicThru IDirectMusicThru8, *LPDIRECTMUSICTHRU8;
typedef struct IReferenceClock *LPREFERENCECLOCK;


/*****************************************************************************
 * Typedef definitions
 */
typedef ULONGLONG    SAMPLE_TIME, *LPSAMPLE_TIME;
typedef ULONGLONG    SAMPLE_POSITION, *LPSAMPLE_POSITION;	


/*****************************************************************************
 * Flags
 */
#ifndef _DIRECTAUDIO_PRIORITIES_DEFINED_
#define _DIRECTAUDIO_PRIORITIES_DEFINED_

#define DAUD_CRITICAL_VOICE_PRIORITY 0xF0000000
#define DAUD_HIGH_VOICE_PRIORITY     0xC0000000
#define DAUD_STANDARD_VOICE_PRIORITY 0x80000000
#define DAUD_LOW_VOICE_PRIORITY      0x40000000
#define DAUD_PERSIST_VOICE_PRIORITY  0x10000000

#define DAUD_CHAN1_VOICE_PRIORITY_OFFSET  0x0000000E
#define DAUD_CHAN2_VOICE_PRIORITY_OFFSET  0x0000000D
#define DAUD_CHAN3_VOICE_PRIORITY_OFFSET  0x0000000C
#define DAUD_CHAN4_VOICE_PRIORITY_OFFSET  0x0000000B
#define DAUD_CHAN5_VOICE_PRIORITY_OFFSET  0x0000000A
#define DAUD_CHAN6_VOICE_PRIORITY_OFFSET  0x00000009
#define DAUD_CHAN7_VOICE_PRIORITY_OFFSET  0x00000008
#define DAUD_CHAN8_VOICE_PRIORITY_OFFSET  0x00000007
#define DAUD_CHAN9_VOICE_PRIORITY_OFFSET  0x00000006
#define DAUD_CHAN10_VOICE_PRIORITY_OFFSET 0x0000000F
#define DAUD_CHAN11_VOICE_PRIORITY_OFFSET 0x00000005
#define DAUD_CHAN12_VOICE_PRIORITY_OFFSET 0x00000004
#define DAUD_CHAN13_VOICE_PRIORITY_OFFSET 0x00000003
#define DAUD_CHAN14_VOICE_PRIORITY_OFFSET 0x00000002
#define DAUD_CHAN15_VOICE_PRIORITY_OFFSET 0x00000001
#define DAUD_CHAN16_VOICE_PRIORITY_OFFSET 0x00000000

#define DAUD_CHAN1_DEF_VOICE_PRIORITY  (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN1_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN2_DEF_VOICE_PRIORITY  (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN2_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN3_DEF_VOICE_PRIORITY  (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN3_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN4_DEF_VOICE_PRIORITY  (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN4_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN5_DEF_VOICE_PRIORITY  (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN5_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN6_DEF_VOICE_PRIORITY  (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN6_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN7_DEF_VOICE_PRIORITY  (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN7_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN8_DEF_VOICE_PRIORITY  (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN8_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN9_DEF_VOICE_PRIORITY  (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN9_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN10_DEF_VOICE_PRIORITY (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN10_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN11_DEF_VOICE_PRIORITY (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN11_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN12_DEF_VOICE_PRIORITY (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN12_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN13_DEF_VOICE_PRIORITY (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN13_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN14_DEF_VOICE_PRIORITY (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN14_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN15_DEF_VOICE_PRIORITY (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN15_VOICE_PRIORITY_OFFSET)
#define DAUD_CHAN16_DEF_VOICE_PRIORITY (DAUD_STANDARD_VOICE_PRIORITY | DAUD_CHAN16_VOICE_PRIORITY_OFFSET)
#endif  /* _DIRECTAUDIO_PRIORITIES_DEFINED_ */

#define DMUS_CLOCKF_GLOBAL 0x1

#define DMUS_EFFECT_NONE   0x0
#define DMUS_EFFECT_REVERB 0x1
#define DMUS_EFFECT_CHORUS 0x2
#define DMUS_EFFECT_DELAY  0x4
	
#define DMUS_MAX_DESCRIPTION 0x80
#define DMUS_MAX_DRIVER 0x80

#define DMUS_PC_INPUTCLASS  0x0
#define DMUS_PC_OUTPUTCLASS 0x1

#define DMUS_PC_DLS             0x00000001
#define DMUS_PC_EXTERNAL        0x00000002
#define DMUS_PC_SOFTWARESYNTH   0x00000004
#define DMUS_PC_MEMORYSIZEFIXED 0x00000008
#define DMUS_PC_GMINHARDWARE    0x00000010
#define DMUS_PC_GSINHARDWARE    0x00000020
#define DMUS_PC_XGINHARDWARE    0x00000040
#define DMUS_PC_DIRECTSOUND     0x00000080
#define DMUS_PC_SHAREABLE       0x00000100
#define DMUS_PC_DLS2            0x00000200
#define DMUS_PC_AUDIOPATH       0x00000400
#define DMUS_PC_WAVE            0x00000800
#define DMUS_PC_SYSTEMMEMORY    0x7FFFFFFF

#define DMUS_PORT_WINMM_DRIVER    0x0
#define DMUS_PORT_USER_MODE_SYNTH 0x1
#define DMUS_PORT_KERNEL_MODE     0x2

#define DMUS_PORT_FEATURE_AUDIOPATH     0x1
#define DMUS_PORT_FEATURE_STREAMING     0x2

#define DMUS_PORTPARAMS_VOICES           0x01
#define DMUS_PORTPARAMS_CHANNELGROUPS    0x02
#define DMUS_PORTPARAMS_AUDIOCHANNELS    0x04
#define DMUS_PORTPARAMS_SAMPLERATE       0x08
#define DMUS_PORTPARAMS_EFFECTS          0x20
#define DMUS_PORTPARAMS_SHARE            0x40
#define DMUS_PORTPARAMS_FEATURES         0x80

#define DMUS_VOLUME_MAX     2000
#define DMUS_VOLUME_MIN   -20000

#define DMUS_SYNTHSTATS_VOICES        0x01
#define DMUS_SYNTHSTATS_TOTAL_CPU     0x02
#define DMUS_SYNTHSTATS_CPU_PER_VOICE 0x04
#define DMUS_SYNTHSTATS_LOST_NOTES    0x08
#define DMUS_SYNTHSTATS_PEAK_VOLUME   0x10
#define DMUS_SYNTHSTATS_FREE_MEMORY   0x20
#define DMUS_SYNTHSTATS_SYSTEMMEMORY  DMUS_PC_SYSTEMMEMORY

#define DSBUSID_FIRST_SPKR_LOC        0x00000000
#define DSBUSID_FRONT_LEFT            0x00000000
#define DSBUSID_LEFT                  0x00000000
#define DSBUSID_FRONT_RIGHT           0x00000001
#define DSBUSID_RIGHT                 0x00000001
#define DSBUSID_FRONT_CENTER          0x00000002
#define DSBUSID_LOW_FREQUENCY         0x00000003
#define DSBUSID_BACK_LEFT             0x00000004
#define DSBUSID_BACK_RIGHT            0x00000005
#define DSBUSID_FRONT_LEFT_OF_CENTER  0x00000006 
#define DSBUSID_FRONT_RIGHT_OF_CENTER 0x00000007
#define DSBUSID_BACK_CENTER           0x00000008
#define DSBUSID_SIDE_LEFT             0x00000009
#define DSBUSID_SIDE_RIGHT            0x0000000A
#define DSBUSID_TOP_CENTER            0x0000000B
#define DSBUSID_TOP_FRONT_LEFT        0x0000000C
#define DSBUSID_TOP_FRONT_CENTER      0x0000000D
#define DSBUSID_TOP_FRONT_RIGHT       0x0000000E
#define DSBUSID_TOP_BACK_LEFT         0x0000000F
#define DSBUSID_TOP_BACK_CENTER       0x00000010
#define DSBUSID_TOP_BACK_RIGHT        0x011
#define DSBUSID_LAST_SPKR_LOC         0x00000011
#define DSBUSID_IS_SPKR_LOC(id)       (((id) >= DSBUSID_FIRST_SPKR_LOC) && ((id) <= DSBUSID_LAST_SPKR_LOC))

#define DSBUSID_REVERB_SEND           0x00000040
#define DSBUSID_CHORUS_SEND           0x00000041

#define DSBUSID_DYNAMIC_0             0x00000200 

#define DSBUSID_NULL			      0xFFFFFFFF

/*****************************************************************************
 * Enumerations
 */
typedef enum {
	DMUS_CLOCK_SYSTEM = 0x0,
	DMUS_CLOCK_WAVE   = 0x1
} DMUS_CLOCKTYPE;


/*****************************************************************************
 * Structures
 */
/* typedef definitions */
typedef struct _DMUS_BUFFERDESC          DMUS_BUFFERDESC,          *LPDMUS_BUFFERDESC;
typedef struct _DMUS_PORTCAPS            DMUS_PORTCAPS,            *LPDMUS_PORTCAPS;
typedef struct _DMUS_PORTPARAMS          DMUS_PORTPARAMS7,         *LPDMUS_PORTPARAMS7;
typedef struct _DMUS_PORTPARAMS8         DMUS_PORTPARAMS8,         *LPDMUS_PORTPARAMS8;
typedef         DMUS_PORTPARAMS8         DMUS_PORTPARAMS,          *LPDMUS_PORTPARAMS;
typedef struct _DMUS_SYNTHSTATS          DMUS_SYNTHSTATS,          *LPDMUS_SYNTHSTATS;
typedef struct _DMUS_SYNTHSTATS8         DMUS_SYNTHSTATS8,         *LPDMUS_SYNTHSTATS8;
typedef struct _DMUS_WAVES_REVERB_PARAMS DMUS_WAVES_REVERB_PARAMS, *LPDMUS_WAVES_REVERB_PARAMS;
typedef struct _DMUS_CLOCKINFO7          DMUS_CLOCKINFO7,          *LPDMUS_CLOCKINFO7;
typedef struct _DMUS_CLOCKINFO8          DMUS_CLOCKINFO8,          *LPDMUS_CLOCKINFO8;
typedef         DMUS_CLOCKINFO8          DMUS_CLOCKINFO,           *LPDMUS_CLOCKINFO;


/* actual structures */
struct _DMUS_BUFFERDESC {
	DWORD dwSize;
	DWORD dwFlags;
	GUID guidBufferFormat;
	DWORD cbBuffer;
} ;

struct _DMUS_PORTCAPS {
	DWORD dwSize;
	DWORD dwFlags;
	GUID  guidPort;
	DWORD dwClass;
	DWORD dwType;
	DWORD dwMemorySize;
	DWORD dwMaxChannelGroups;
	DWORD dwMaxVoices;    
	DWORD dwMaxAudioChannels;
	DWORD dwEffectFlags;
	WCHAR wszDescription[DMUS_MAX_DESCRIPTION];
};

struct _DMUS_PORTPARAMS {
	DWORD dwSize;
	DWORD dwValidParams;
	DWORD dwVoices;
	DWORD dwChannelGroups;
	DWORD dwAudioChannels;
	DWORD dwSampleRate;
	DWORD dwEffectFlags;
	WINBOOL  fShare;
};

struct _DMUS_PORTPARAMS8 {
	DWORD dwSize;
	DWORD dwValidParams;
	DWORD dwVoices;
	DWORD dwChannelGroups;
	DWORD dwAudioChannels;
	DWORD dwSampleRate;
	DWORD dwEffectFlags;
	WINBOOL  fShare;
	DWORD dwFeatures;
};

struct _DMUS_SYNTHSTATS {
	DWORD dwSize;
	DWORD dwValidStats;
	DWORD dwVoices;
	DWORD dwTotalCPU;
	DWORD dwCPUPerVoice;
	DWORD dwLostNotes;
	DWORD dwFreeMemory;
	LONG  lPeakVolume;
};

struct _DMUS_SYNTHSTATS8 {
	DWORD dwSize;
	DWORD dwValidStats;
	DWORD dwVoices;
	DWORD dwTotalCPU;
	DWORD dwCPUPerVoice;
	DWORD dwLostNotes;
	DWORD dwFreeMemory;
	LONG  lPeakVolume;
	DWORD dwSynthMemUse;
};

struct _DMUS_WAVES_REVERB_PARAMS {
	float fInGain;
	float fReverbMix;
	float fReverbTime;
	float fHighFreqRTRatio;
};

struct _DMUS_CLOCKINFO7 {
	DWORD          dwSize;
	DMUS_CLOCKTYPE ctType;
	GUID           guidClock;
	WCHAR          wszDescription[DMUS_MAX_DESCRIPTION];
};

struct _DMUS_CLOCKINFO8 {
    DWORD          dwSize;
    DMUS_CLOCKTYPE ctType;
    GUID           guidClock;
    WCHAR          wszDescription[DMUS_MAX_DESCRIPTION];
    DWORD          dwFlags;           
};


/*****************************************************************************
 * IDirectMusic interface
 */
#define INTERFACE IDirectMusic
DECLARE_INTERFACE_(IDirectMusic,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusic methods ***/
    STDMETHOD(EnumPort)(THIS_ DWORD dwIndex, LPDMUS_PORTCAPS pPortCaps) PURE;
    STDMETHOD(CreateMusicBuffer)(THIS_ LPDMUS_BUFFERDESC pBufferDesc, LPDIRECTMUSICBUFFER *ppBuffer, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(CreatePort)(THIS_ REFCLSID rclsidPort, LPDMUS_PORTPARAMS pPortParams, LPDIRECTMUSICPORT *ppPort, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumMasterClock)(THIS_ DWORD dwIndex, LPDMUS_CLOCKINFO lpClockInfo) PURE;
    STDMETHOD(GetMasterClock)(THIS_ LPGUID pguidClock, struct IReferenceClock **ppReferenceClock) PURE;
    STDMETHOD(SetMasterClock)(THIS_ REFGUID rguidClock) PURE;
    STDMETHOD(Activate)(THIS_ WINBOOL fEnable) PURE;
    STDMETHOD(GetDefaultPort)(THIS_ LPGUID pguidPort) PURE;
    STDMETHOD(SetDirectSound)(THIS_ LPDIRECTSOUND pDirectSound, HWND hWnd) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusic_QueryInterface(p,a,b)      (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusic_AddRef(p)                  (p)->lpVtbl->AddRef(p)
#define IDirectMusic_Release(p)                 (p)->lpVtbl->Release(p)
/*** IDirectMusic methods ***/
#define IDirectMusic_EnumPort(p,a,b)            (p)->lpVtbl->EnumPort(p,a,b)
#define IDirectMusic_CreateMusicBuffer(p,a,b,c) (p)->lpVtbl->CreateMusicBuffer(p,a,b,c)
#define IDirectMusic_CreatePort(p,a,b,c,d)      (p)->lpVtbl->CreatePort(p,a,b,c,d)
#define IDirectMusic_EnumMasterClock(p,a,b)     (p)->lpVtbl->EnumMasterClock(p,a,b)
#define IDirectMusic_GetMasterClock(p,a,b)      (p)->lpVtbl->GetMasterClock(p,a,b)
#define IDirectMusic_SetMasterClock(p,a)        (p)->lpVtbl->SetMasterClock(p,a)
#define IDirectMusic_Activate(p,a)              (p)->lpVtbl->Activate(p,a)
#define IDirectMusic_GetDefaultPort(p,a)        (p)->lpVtbl->GetDefaultPort(p,a)
#define IDirectMusic_SetDirectSound(p,a,b)      (p)->lpVtbl->SetDirectSound(p,a,b)
#endif


/*****************************************************************************
 * IDirectMusic8 interface
 */
#define INTERFACE IDirectMusic8
DECLARE_INTERFACE_(IDirectMusic8,IDirectMusic)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusic methods ***/
    STDMETHOD(EnumPort)(THIS_ DWORD dwIndex, LPDMUS_PORTCAPS pPortCaps) PURE;
    STDMETHOD(CreateMusicBuffer)(THIS_ LPDMUS_BUFFERDESC pBufferDesc, LPDIRECTMUSICBUFFER *ppBuffer, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(CreatePort)(THIS_ REFCLSID rclsidPort, LPDMUS_PORTPARAMS pPortParams, LPDIRECTMUSICPORT *ppPort, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumMasterClock)(THIS_ DWORD dwIndex, LPDMUS_CLOCKINFO lpClockInfo) PURE;
    STDMETHOD(GetMasterClock)(THIS_ LPGUID pguidClock, struct IReferenceClock **ppReferenceClock) PURE;
    STDMETHOD(SetMasterClock)(THIS_ REFGUID rguidClock) PURE;
    STDMETHOD(Activate)(THIS_ WINBOOL fEnable) PURE;
    STDMETHOD(GetDefaultPort)(THIS_ LPGUID pguidPort) PURE;
    STDMETHOD(SetDirectSound)(THIS_ LPDIRECTSOUND pDirectSound, HWND hWnd) PURE;
    /*** IDirectMusic8 methods ***/
    STDMETHOD(SetExternalMasterClock)(THIS_ struct IReferenceClock *pClock) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusic8_QueryInterface(p,a,b)       (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusic8_AddRef(p)                   (p)->lpVtbl->AddRef(p)
#define IDirectMusic8_Release(p)                  (p)->lpVtbl->Release(p)
/*** IDirectMusic methods ***/
#define IDirectMusic8_EnumPort(p,a,b)             (p)->lpVtbl->EnumPort(p,a,b)
#define IDirectMusic8_CreateMusicBuffer(p,a,b,c)  (p)->lpVtbl->CreateMusicBuffer(p,a,b,c)
#define IDirectMusic8_CreatePort(p,a,b,c,d)       (p)->lpVtbl->CreatePort(p,a,b,c,d)
#define IDirectMusic8_EnumMasterClock(p,a,b)      (p)->lpVtbl->EnumMasterClock(p,a,b)
#define IDirectMusic8_GetMasterClock(p,a,b)       (p)->lpVtbl->GetMasterClock(p,a,b)
#define IDirectMusic8_SetMasterClock(p,a)         (p)->lpVtbl->SetMasterClock(p,a)
#define IDirectMusic8_Activate(p,a)               (p)->lpVtbl->Activate(p,a)
#define IDirectMusic8_GetDefaultPort(p,a)         (p)->lpVtbl->GetDefaultPort(p,a)
#define IDirectMusic8_SetDirectSound(p,a,b)       (p)->lpVtbl->SetDirectSound(p,a,b)
/*** IDirectMusic8 methods ***/
#define IDirectMusic8_SetExternalMasterClock(p,a) (p)->lpVtbl->SetExternalMasterClock(p,a)
#endif


/*****************************************************************************
 * IDirectMusicBuffer interface
 */
#define INTERFACE IDirectMusicBuffer
DECLARE_INTERFACE_(IDirectMusicBuffer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicBuffer methods ***/
    STDMETHOD(Flush)(THIS) PURE;
    STDMETHOD(TotalTime)(THIS_ LPREFERENCE_TIME prtTime) PURE;
    STDMETHOD(PackStructured)(THIS_ REFERENCE_TIME rt, DWORD dwChannelGroup, DWORD dwChannelMessage) PURE;
    STDMETHOD(PackUnstructured)(THIS_ REFERENCE_TIME rt, DWORD dwChannelGroup, DWORD cb, LPBYTE lpb) PURE;
    STDMETHOD(ResetReadPtr)(THIS) PURE;
    STDMETHOD(GetNextEvent)(THIS_ LPREFERENCE_TIME prt, LPDWORD pdwChannelGroup, LPDWORD pdwLength, LPBYTE *ppData) PURE;
    STDMETHOD(GetRawBufferPtr)(THIS_ LPBYTE *ppData) PURE;
    STDMETHOD(GetStartTime)(THIS_ LPREFERENCE_TIME prt) PURE;
    STDMETHOD(GetUsedBytes)(THIS_ LPDWORD pcb) PURE;
    STDMETHOD(GetMaxBytes)(THIS_ LPDWORD pcb) PURE;
    STDMETHOD(GetBufferFormat)(THIS_ LPGUID pGuidFormat) PURE;
    STDMETHOD(SetStartTime)(THIS_ REFERENCE_TIME rt) PURE;
    STDMETHOD(SetUsedBytes)(THIS_ DWORD cb) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicBuffer_QueryInterface(p,a,b)            (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicBuffer_AddRef(p)                        (p)->lpVtbl->AddRef(p)
#define IDirectMusicBuffer_Release(p)                       (p)->lpVtbl->Release(p)
/*** IDirectMusicBuffer methods ***/
#define IDirectMusicBuffer_Flush(p)                         (p)->lpVtbl->Flush(p)
#define IDirectMusicBuffer_TotalTime(p,a)                   (p)->lpVtbl->TotalTime(p,a)
#define IDirectMusicBuffer_PackStructured(p,a,b,c)          (p)->lpVtbl->PackStructured(p,a,b,c)
#define IDirectMusicBuffer_PackUnstructured(p,a,b,c,d)      (p)->lpVtbl->PackUnstructured(p,a,b,c,d)
#define IDirectMusicBuffer_ResetReadPtr(p)                  (p)->lpVtbl->ResetReadPtr(p)
#define IDirectMusicBuffer_GetNextEvent(p,a,b,c,d)          (p)->lpVtbl->GetNextEvent(p,a,b,c,d)
#define IDirectMusicBuffer_GetRawBufferPtr(p,a)             (p)->lpVtbl->GetRawBufferPtr(p,a)
#define IDirectMusicBuffer_GetStartTime(p,a)                (p)->lpVtbl->GetStartTime(p,a)
#define IDirectMusicBuffer_GetUsedBytes(p,a)                (p)->lpVtbl->GetUsedBytes(p,a)
#define IDirectMusicBuffer_GetMaxBytes(p,a)                 (p)->lpVtbl->GetMaxBytes(p,a)
#define IDirectMusicBuffer_GetBufferFormat(p,a)             (p)->lpVtbl->GetBufferFormat(p,a)
#define IDirectMusicBuffer_SetStartTime(p,a)                (p)->lpVtbl->SetStartTime(p,a)
#define IDirectMusicBuffer_SetUsedBytes(p,a)                (p)->lpVtbl->SetUsedBytes(p,a)
#endif


/*****************************************************************************
 * IDirectMusicInstrument interface
 */
#define INTERFACE IDirectMusicInstrument
DECLARE_INTERFACE_(IDirectMusicInstrument,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicInstrument methods ***/
    STDMETHOD(GetPatch)(THIS_ DWORD *pdwPatch) PURE;
    STDMETHOD(SetPatch)(THIS_ DWORD dwPatch) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicInstrument_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicInstrument_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectMusicInstrument_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectMusicInstrument methods ***/
#define IDirectMusicInstrument_GetPatch(p,a)         (p)->lpVtbl->GetPatch(p,a)
#define IDirectMusicInstrument_SetPatch(p,a)         (p)->lpVtbl->SetPatch(p,a)
#endif


/*****************************************************************************
 * IDirectMusicDownloadedInstrument interface
 */
#define INTERFACE IDirectMusicDownloadedInstrument
DECLARE_INTERFACE_(IDirectMusicDownloadedInstrument,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /* no IDirectMusicDownloadedInstrument methods at this time */
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicDownloadedInstrument_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicDownloadedInstrument_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectMusicDownloadedInstrument_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectMusicDownloadedInstrument methods ***/
/* none at this time */
#endif


/*****************************************************************************
 * IDirectMusicCollection interface
 */
#define INTERFACE IDirectMusicCollection
DECLARE_INTERFACE_(IDirectMusicCollection,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicCollection methods ***/
    STDMETHOD(GetInstrument)(THIS_ DWORD dwPatch, IDirectMusicInstrument **ppInstrument) PURE;
    STDMETHOD(EnumInstrument)(THIS_ DWORD dwIndex, DWORD *pdwPatch, LPWSTR pwszName, DWORD dwNameLen) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicCollection_QueryInterface(p,a,b)            (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicCollection_AddRef(p)                        (p)->lpVtbl->AddRef(p)
#define IDirectMusicCollection_Release(p)                       (p)->lpVtbl->Release(p)
/*** IDirectMusicCollection methods ***/
#define IDirectMusicCollection_GetInstrument(p,a,b)             (p)->lpVtbl->GetInstrument(p,a,b)
#define IDirectMusicCollection_EnumInstrument(p,a,b,c,d)        (p)->lpVtbl->EnumInstrument(p,a,b,c,d)
#endif


/*****************************************************************************
 * IDirectMusicDownload interface
 */
#define INTERFACE IDirectMusicDownload
DECLARE_INTERFACE_(IDirectMusicDownload,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicDownload methods ***/
    STDMETHOD(GetBuffer)(THIS_ void **ppvBuffer, DWORD *pdwSize) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicDownload_QueryInterface(p,a,b)          (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicDownload_AddRef(p)                      (p)->lpVtbl->AddRef(p)
#define IDirectMusicDownload_Release(p)                     (p)->lpVtbl->Release(p)
/*** IDirectMusicDownload methods ***/
#define IDirectMusicDownload_GetBuffer(p,a,b)               (p)->lpVtbl->GetBuffer(p,a,b)
#endif


/*****************************************************************************
 * IDirectMusicPortDownload interface
 */
#define INTERFACE IDirectMusicPortDownload
DECLARE_INTERFACE_(IDirectMusicPortDownload,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicPortDownload methods ***/
    STDMETHOD(GetBuffer)(THIS_ DWORD dwDLId, IDirectMusicDownload **ppIDMDownload) PURE;
    STDMETHOD(AllocateBuffer)(THIS_ DWORD dwSize, IDirectMusicDownload **ppIDMDownload) PURE;
    STDMETHOD(GetDLId)(THIS_ DWORD *pdwStartDLId, DWORD dwCount) PURE;
    STDMETHOD(GetAppend)(THIS_ DWORD *pdwAppend) PURE;
    STDMETHOD(Download)(THIS_ IDirectMusicDownload *pIDMDownload) PURE;
    STDMETHOD(Unload)(THIS_ IDirectMusicDownload *pIDMDownload) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicPortDownload_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicPortDownload_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectMusicPortDownload_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectMusicPortDownload methods ***/
#define IDirectMusicPortDownload_GetBuffer(p,a,b)      (p)->lpVtbl->GetBuffer(p,a,b)
#define IDirectMusicPortDownload_AllocateBuffer(p,a,b) (p)->lpVtbl->AllocateBuffer(p,a,b)
#define IDirectMusicPortDownload_GetDLId(p,a,b)        (p)->lpVtbl->GetDLId(p,a,b)
#define IDirectMusicPortDownload_GetAppend(p,a)        (p)->lpVtbl->GetAppend(p,a)
#define IDirectMusicPortDownload_Download(p,a)         (p)->lpVtbl->Download(p,a)
#define IDirectMusicPortDownload_Unload(p,a)           (p)->lpVtbl->GetBuffer(p,a)
#endif


/*****************************************************************************
 * IDirectMusicPort interface
 */
#define INTERFACE IDirectMusicPort
DECLARE_INTERFACE_(IDirectMusicPort,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicPort methods ***/
    STDMETHOD(PlayBuffer)(THIS_ LPDIRECTMUSICBUFFER pBuffer) PURE;
    STDMETHOD(SetReadNotificationHandle)(THIS_ HANDLE hEvent) PURE;
    STDMETHOD(Read)(THIS_ LPDIRECTMUSICBUFFER pBuffer) PURE;
    STDMETHOD(DownloadInstrument)(THIS_ IDirectMusicInstrument *pInstrument, IDirectMusicDownloadedInstrument **ppDownloadedInstrument, DMUS_NOTERANGE *pNoteRanges, DWORD dwNumNoteRanges) PURE;
    STDMETHOD(UnloadInstrument)(THIS_ IDirectMusicDownloadedInstrument *pDownloadedInstrument) PURE;
    STDMETHOD(GetLatencyClock)(THIS_ struct IReferenceClock **ppClock) PURE;
    STDMETHOD(GetRunningStats)(THIS_ LPDMUS_SYNTHSTATS pStats) PURE;
    STDMETHOD(Compact)(THIS) PURE;
    STDMETHOD(GetCaps)(THIS_ LPDMUS_PORTCAPS pPortCaps) PURE;
    STDMETHOD(DeviceIoControl)(THIS_ DWORD dwIoControlCode, LPVOID lpInBuffer, DWORD nInBufferSize, LPVOID lpOutBuffer, DWORD nOutBufferSize, LPDWORD lpBytesReturned, LPOVERLAPPED lpOverlapped) PURE;
    STDMETHOD(SetNumChannelGroups)(THIS_ DWORD dwChannelGroups) PURE;
    STDMETHOD(GetNumChannelGroups)(THIS_ LPDWORD pdwChannelGroups) PURE;
    STDMETHOD(Activate)(THIS_ WINBOOL fActive) PURE;
    STDMETHOD(SetChannelPriority)(THIS_ DWORD dwChannelGroup, DWORD dwChannel, DWORD dwPriority) PURE;
    STDMETHOD(GetChannelPriority)(THIS_ DWORD dwChannelGroup, DWORD dwChannel, LPDWORD pdwPriority) PURE;
    STDMETHOD(SetDirectSound)(THIS_ LPDIRECTSOUND pDirectSound, LPDIRECTSOUNDBUFFER pDirectSoundBuffer) PURE;
    STDMETHOD(GetFormat)(THIS_ LPWAVEFORMATEX pWaveFormatEx, LPDWORD pdwWaveFormatExSize, LPDWORD pdwBufferSize) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicPort_QueryInterface(p,a,b)            (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicPort_AddRef(p)                        (p)->lpVtbl->AddRef(p)
#define IDirectMusicPort_Release(p)                       (p)->lpVtbl->Release(p)
/*** IDirectMusicPort methods ***/
#define IDirectMusicPort_PlayBuffer(p,a)                  (p)->lpVtbl->PlayBuffer(p,a)
#define IDirectMusicPort_SetReadNotificationHandle(p,a)   (p)->lpVtbl->SetReadNotificationHandle(p,a)
#define IDirectMusicPort_Read(p,a)                        (p)->lpVtbl->Read(p,a)
#define IDirectMusicPort_DownloadInstrument(p,a,b,c,d)    (p)->lpVtbl->DownloadInstrument(p,a,b,c,d)
#define IDirectMusicPort_UnloadInstrument(p,a)            (p)->lpVtbl->UnloadInstrument(p,a)
#define IDirectMusicPort_GetLatencyClock(p,a)             (p)->lpVtbl->GetLatencyClock(p,a)
#define IDirectMusicPort_GetRunningStats(p,a)             (p)->lpVtbl->GetRunningStats(p,a)
#define IDirectMusicPort_Compact(p)                       (p)->lpVtbl->Compact(p)
#define IDirectMusicPort_GetCaps(p,a)                     (p)->lpVtbl->GetCaps(p,a)
#define IDirectMusicPort_DeviceIoControl(p,a,b,c,d,e,f,g) (p)->lpVtbl->DeviceIoControl(p,a,b,c,d,e,f,g)
#define IDirectMusicPort_SetNumChannelGroups(p,a)         (p)->lpVtbl->SetNumChannelGroups(p,a)
#define IDirectMusicPort_GetNumChannelGroups(p,a)         (p)->lpVtbl->GetNumChannelGroups(p,a)
#define IDirectMusicPort_Activate(p,a)                    (p)->lpVtbl->Activate(p,a)
#define IDirectMusicPort_SetChannelPriority(p,a,b,c)      (p)->lpVtbl->SetChannelPriority(p,a,b,c)
#define IDirectMusicPort_GetChannelPriority(p,a,b,c)      (p)->lpVtbl->GetChannelPriority(p,a,b,c)
#define IDirectMusicPort_SetDirectSound(p,a,b)            (p)->lpVtbl->SetDirectSound(p,a,b)
#define IDirectMusicPort_GetFormat(p,a,b,c)               (p)->lpVtbl->GetFormat(p,a,b,c)
#endif


/*****************************************************************************
 * IDirectMusicThru interface
 */
#define INTERFACE IDirectMusicThru
DECLARE_INTERFACE_(IDirectMusicThru,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicThru methods ***/
    STDMETHOD(ThruChannel)(THIS_ DWORD dwSourceChannelGroup, DWORD dwSourceChannel, DWORD dwDestinationChannelGroup, DWORD dwDestinationChannel, LPDIRECTMUSICPORT pDestinationPort) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicThru_QueryInterface(p,a,b)                  (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicThru_AddRef(p)                              (p)->lpVtbl->AddRef(p)
#define IDirectMusicThru_Release(p)                             (p)->lpVtbl->Release(p)
/*** IDirectMusicThru methods ***/
#define IDirectMusicThru_ThruChannel(p,a,b,c,d,e)               (p)->lpVtbl->ThruChannel(p,a,b,c,d,e)
#endif


#ifndef __IReferenceClock_INTERFACE_DEFINED__
#define __IReferenceClock_INTERFACE_DEFINED__
DEFINE_GUID(IID_IReferenceClock,0x56a86897,0x0ad4,0x11ce,0xb0,0x3a,0x00,0x20,0xaf,0x0b,0xa7,0x70);

/*****************************************************************************
 * IReferenceClock interface
 */
#define INTERFACE IReferenceClock
DECLARE_INTERFACE_(IReferenceClock,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IReferenceClock methods ***/
    STDMETHOD(GetTime)(THIS_ REFERENCE_TIME *pTime) PURE;
    STDMETHOD(AdviseTime)(THIS_ REFERENCE_TIME baseTime, REFERENCE_TIME streamTime, HANDLE hEvent, DWORD *pdwAdviseCookie) PURE;
    STDMETHOD(AdvisePeriodic)(THIS_ REFERENCE_TIME startTime, REFERENCE_TIME periodTime, HANDLE hSemaphore, DWORD *pdwAdviseCookie) PURE;
    STDMETHOD(Unadvise)(THIS_ DWORD dwAdviseCookie) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IReferenceClock_QueryInterface(p,a,b)                   (p)->lpVtbl->QueryInterface(p,a,b)
#define IReferenceClock_AddRef(p)                               (p)->lpVtbl->AddRef(p)
#define IReferenceClock_Release(p)                              (p)->lpVtbl->Release(p)
/*** IReferenceClock methods ***/
#define IReferenceClock_GetTime(p,a)                            (p)->lpVtbl->GetTime(p,a)
#define IReferenceClock_AdviseTime(p,a,b,c,d)                   (p)->lpVtbl->AdviseTime(p,a,b,c,d)
#define IReferenceClock_AdvisePeriodic(p,a,b,c,d)               (p)->lpVtbl->AdvisePeriodic(p,a,b,c,d)
#define IReferenceClock_Unadvise(p,a)                           (p)->lpVtbl->Unadvise(p,a)
#endif

#endif /* __IReferenceClock_INTERFACE_DEFINED__ */

#ifdef __cplusplus
}
#endif

#include <poppack.h>

#endif /* __WINE_DMUSIC_CORE_H */
