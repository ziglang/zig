/*
 * Copyright (C) the Wine project
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#include <_mingw_unicode.h>
#undef INTERFACE

#ifndef __DSOUND_INCLUDED__
#define __DSOUND_INCLUDED__

#ifndef DIRECTSOUND_VERSION
#define DIRECTSOUND_VERSION 0x0900
#endif

#define COM_NO_WINDOWS_H
#include <objbase.h>
#include <float.h>

#ifdef __cplusplus
extern "C" {
#endif /* defined(__cplusplus) */

#ifndef DX_SHARED_DEFINES

typedef float D3DVALUE, *LPD3DVALUE;

#ifndef D3DCOLOR_DEFINED
typedef DWORD D3DCOLOR, *LPD3DCOLOR;
#define D3DCOLOR_DEFINED
#endif

#ifndef D3DVECTOR_DEFINED
typedef struct _D3DVECTOR {
    float x;
    float y;
    float z;
} D3DVECTOR;
#define D3DVECTOR_DEFINED
#endif

#ifndef LPD3DVECTOR_DEFINED
typedef D3DVECTOR *LPD3DVECTOR;
#define LPD3DVECTOR_DEFINED
#endif

#define DX_SHARED_DEFINES
#endif /* DX_SHARED_DEFINES */

/*****************************************************************************
 * Predeclare the interfaces
 */
DEFINE_GUID(CLSID_DirectSound,		0x47d4d946, 0x62e8, 0x11cf, 0x93, 0xbc, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00);
DEFINE_GUID(CLSID_DirectSound8,		0x3901cc3f, 0x84b5, 0x4fa4, 0xba, 0x35, 0xaa, 0x81, 0x72, 0xb8, 0xa0, 0x9b);
DEFINE_GUID(CLSID_DirectSoundCapture,	0xb0210780, 0x89cd, 0x11d0, 0xaf, 0x08, 0x00, 0xa0, 0xc9, 0x25, 0xcd, 0x16);
DEFINE_GUID(CLSID_DirectSoundCapture8,	0xe4bcac13, 0x7f99, 0x4908, 0x9a, 0x8e, 0x74, 0xe3, 0xbf, 0x24, 0xb6, 0xe1);
DEFINE_GUID(CLSID_DirectSoundFullDuplex,0xfea4300c, 0x7959, 0x4147, 0xb2, 0x6a, 0x23, 0x77, 0xb9, 0xe7, 0xa9, 0x1d);

DEFINE_GUID(IID_IDirectSound,		0x279AFA83,0x4981,0x11CE,0xA5,0x21,0x00,0x20,0xAF,0x0B,0xE5,0x60);
typedef struct IDirectSound *LPDIRECTSOUND,**LPLPDIRECTSOUND;

DEFINE_GUID(IID_IDirectSound8,		0xC50A7E93,0xF395,0x4834,0x9E,0xF6,0x7F,0xA9,0x9D,0xE5,0x09,0x66);
typedef struct IDirectSound8 *LPDIRECTSOUND8,**LPLPDIRECTSOUND8;

DEFINE_GUID(IID_IDirectSoundBuffer,	0x279AFA85,0x4981,0x11CE,0xA5,0x21,0x00,0x20,0xAF,0x0B,0xE5,0x60);
typedef struct IDirectSoundBuffer *LPDIRECTSOUNDBUFFER,**LPLPDIRECTSOUNDBUFFER;

DEFINE_GUID(IID_IDirectSoundBuffer8,	0x6825A449,0x7524,0x4D82,0x92,0x0F,0x50,0xE3,0x6A,0xB3,0xAB,0x1E);
typedef struct IDirectSoundBuffer8 *LPDIRECTSOUNDBUFFER8,**LPLPDIRECTSOUNDBUFFER8;

DEFINE_GUID(IID_IDirectSoundNotify,	0xB0210783,0x89cd,0x11d0,0xAF,0x08,0x00,0xA0,0xC9,0x25,0xCD,0x16);
typedef struct IDirectSoundNotify *LPDIRECTSOUNDNOTIFY,**LPLPDIRECTSOUNDNOTIFY;
#define IDirectSoundNotify8 IDirectSoundNotify
typedef struct IDirectSoundNotify8 *LPDIRECTSOUNDNOTIFY8;
#define	IID_IDirectSoundNotify8		IID_IDirectSoundNotify

DEFINE_GUID(IID_IDirectSound3DListener,	0x279AFA84,0x4981,0x11CE,0xA5,0x21,0x00,0x20,0xAF,0x0B,0xE5,0x60);
typedef struct IDirectSound3DListener *LPDIRECTSOUND3DLISTENER,**LPLPDIRECTSOUND3DLISTENER;
#define IDirectSound3DListener8 IDirectSound3DListener
typedef struct IDirectSound3DListener8 *LPDIRECTSOUND3DLISTENER8;
#define IID_IDirectSound3DListener8 IID_IDirectSound3DListener

DEFINE_GUID(IID_IDirectSound3DBuffer,	0x279AFA86,0x4981,0x11CE,0xA5,0x21,0x00,0x20,0xAF,0x0B,0xE5,0x60);
typedef struct IDirectSound3DBuffer *LPDIRECTSOUND3DBUFFER,**LPLPDIRECTSOUND3DBUFFER;
#define IDirectSound3DBuffer8 IDirectSound3DBuffer
typedef struct IDirectSound3DBuffer8 *LPDIRECTSOUND3DBUFFER8;
#define IID_IDirectSound3DBuffer8 IID_IDirectSound3DBuffer

DEFINE_GUID(IID_IDirectSoundCapture,	0xB0210781,0x89CD,0x11D0,0xAF,0x08,0x00,0xA0,0xC9,0x25,0xCD,0x16);
typedef struct IDirectSoundCapture *LPDIRECTSOUNDCAPTURE,**LPLPDIRECTSOUNDCAPTURE;
#define	IID_IDirectSoundCapture8	IID_IDirectSoundCapture
typedef struct IDirectSoundCapture IDirectSoundCapture8,*LPDIRECTSOUNDCAPTURE8,**LPLPDIRECTSOUNDCAPTURE8;

DEFINE_GUID(IID_IDirectSoundCaptureBuffer,0xB0210782,0x89CD,0x11D0,0xAF,0x08,0x00,0xA0,0xC9,0x25,0xCD,0x16);
typedef struct IDirectSoundCaptureBuffer *LPDIRECTSOUNDCAPTUREBUFFER,**LPLPDIRECTSOUNDCAPTUREBUFFER;

DEFINE_GUID(IID_IDirectSoundCaptureBuffer8,0x00990DF4,0x0DBB,0x4872,0x83,0x3E,0x6D,0x30,0x3E,0x80,0xAE,0xB6);
typedef struct IDirectSoundCaptureBuffer8 *LPDIRECTSOUNDCAPTUREBUFFER8,**LPLPDIRECTSOUNDCAPTUREBUFFER8;

DEFINE_GUID(IID_IDirectSoundFullDuplex,	0xEDCB4C7A,0xDAAB,0x4216,0xA4,0x2E,0x6C,0x50,0x59,0x6D,0xDC,0x1D);
typedef struct IDirectSoundFullDuplex *LPDIRECTSOUNDFULLDUPLEX,**LPLPDIRECTSOUNDFULLDUPLEX;
#define IDirectSoundFullDuplex8 IDirectSoundFullDuplex
typedef struct IDirectSoundFullDuplex8 *LPDIRECTSOUNDFULLDUPLEX8;
#define	IID_IDirectSoundFullDuplex8	IID_IDirectSoundFullDuplex

DEFINE_GUID(IID_IDirectSoundFXI3DL2Reverb, 0x4b166a6a, 0x0d66, 0x43f3, 0x80, 0xe3, 0xee, 0x62, 0x80, 0xde, 0xe1, 0xa4);
typedef struct IDirectSoundFXI3DL2Reverb  *LPDIRECTSOUNDFXI3DL2REVERB;
#define IDirectSoundFXI3DL2Reverb8        IDirectSoundFXI3DL2Reverb
#define IID_IDirectSoundFXI3DL2Reverb8    IID_IDirectSoundFXI3DL2Reverb
typedef struct IDirectSoundFXI3DL2Reverb8 *LPDIRECTSOUNDFXI3DL2REVERB8;

DEFINE_GUID(DSDEVID_DefaultPlayback,     0xDEF00000,0x9C6D,0x47Ed,0xAA,0xF1,0x4D,0xDA,0x8F,0x2B,0x5C,0x03);
DEFINE_GUID(DSDEVID_DefaultCapture,      0xDEF00001,0x9C6D,0x47Ed,0xAA,0xF1,0x4D,0xDA,0x8F,0x2B,0x5C,0x03);
DEFINE_GUID(DSDEVID_DefaultVoicePlayback,0xDEF00002,0x9C6D,0x47Ed,0xAA,0xF1,0x4D,0xDA,0x8F,0x2B,0x5C,0x03);
DEFINE_GUID(DSDEVID_DefaultVoiceCapture, 0xDEF00003,0x9C6D,0x47ED,0xAA,0xF1,0x4D,0xDA,0x8F,0x2B,0x5C,0x03);

#define DS3DALG_DEFAULT GUID_NULL
DEFINE_GUID(DS3DALG_NO_VIRTUALIZATION,      0xc241333f,0x1c1b,0x11d2,0x94,0xf5,0x00,0xc0,0x4f,0xc2,0x8a,0xca);
DEFINE_GUID(DS3DALG_HRTF_FULL,              0xc2413340,0x1c1b,0x11d2,0x94,0xf5,0x00,0xc0,0x4f,0xc2,0x8a,0xca);
DEFINE_GUID(DS3DALG_HRTF_LIGHT,             0xc2413342,0x1c1b,0x11d2,0x94,0xf5,0x00,0xc0,0x4f,0xc2,0x8a,0xca);

DEFINE_GUID(GUID_DSFX_STANDARD_GARGLE,      0xDAFD8210,0x5711,0x4B91,0x9F,0xE3,0xF7,0x5B,0x7A,0xE2,0x79,0xBF);
DEFINE_GUID(GUID_DSFX_STANDARD_CHORUS,      0xEFE6629C,0x81F7,0x4281,0xBD,0x91,0xC9,0xD6,0x04,0xA9,0x5A,0xF6);
DEFINE_GUID(GUID_DSFX_STANDARD_FLANGER,     0xEFCA3D92,0xDFD8,0x4672,0xA6,0x03,0x74,0x20,0x89,0x4B,0xAD,0x98);
DEFINE_GUID(GUID_DSFX_STANDARD_ECHO,        0xEF3E932C,0xD40B,0x4F51,0x8C,0xCF,0x3F,0x98,0xF1,0xB2,0x9D,0x5D);
DEFINE_GUID(GUID_DSFX_STANDARD_DISTORTION,  0xEF114C90,0xCD1D,0x484E,0x96,0xE5,0x09,0xCF,0xAF,0x91,0x2A,0x21);
DEFINE_GUID(GUID_DSFX_STANDARD_COMPRESSOR,  0xEF011F79,0x4000,0x406D,0x87,0xAF,0xBF,0xFB,0x3F,0xC3,0x9D,0x57);
DEFINE_GUID(GUID_DSFX_STANDARD_PARAMEQ,     0x120CED89,0x3BF4,0x4173,0xA1,0x32,0x3C,0xB4,0x06,0xCF,0x32,0x31);
DEFINE_GUID(GUID_DSFX_STANDARD_I3DL2REVERB, 0xEF985E71,0xD5C7,0x42D4,0xBA,0x4D,0x2D,0x07,0x3E,0x2E,0x96,0xF4);
DEFINE_GUID(GUID_DSFX_WAVES_REVERB,         0x87FC0268,0x9A55,0x4360,0x95,0xAA,0x00,0x4A,0x1D,0x9D,0xE2,0x6C);
DEFINE_GUID(GUID_DSCFX_CLASS_AEC,           0xBF963D80,0xC559,0x11D0,0x8A,0x2B,0x00,0xA0,0xC9,0x25,0x5A,0xC1);
DEFINE_GUID(GUID_DSCFX_MS_AEC,              0xCDEBB919,0x379A,0x488A,0x87,0x65,0xF5,0x3C,0xFD,0x36,0xDE,0x40);
DEFINE_GUID(GUID_DSCFX_SYSTEM_AEC,          0x1C22C56D,0x9879,0x4F5B,0xA3,0x89,0x27,0x99,0x6D,0xDC,0x28,0x10);
DEFINE_GUID(GUID_DSCFX_CLASS_NS,            0xE07F903F,0x62FD,0x4E60,0x8C,0xDD,0xDE,0xA7,0x23,0x66,0x65,0xB5);
DEFINE_GUID(GUID_DSCFX_MS_NS,               0x11C5C73B,0x66E9,0x4BA1,0xA0,0xBA,0xE8,0x14,0xC6,0xEE,0xD9,0x2D);
DEFINE_GUID(GUID_DSCFX_SYSTEM_NS,           0x5AB0882E,0x7274,0x4516,0x87,0x7D,0x4E,0xEE,0x99,0xBA,0x4F,0xD0);

DEFINE_GUID(IID_IDirectSoundFXGargle,       0xd616f352,0xd622,0x11ce,0xaa,0xc5,0x00,0x20,0xaf,0x0b,0x99,0xa3);
#define IDirectSoundFXGargle8               IDirectSoundFXGargle
typedef struct IDirectSoundFXGargle8        *LPDIRECTSOUNDFXGARGLE8;
#define IID_IDirectSoundFXGargle8           IID_IDirectSoundFXGargle

DEFINE_GUID(IID_IDirectSoundFXChorus,       0x880842e3,0x145f,0x43e6,0xa9,0x34,0xa7,0x18,0x06,0xe5,0x05,0x47);
#define IDirectSoundFXChorus8               IDirectSoundFXChorus
typedef struct IDirectSoundFXChorus8        *LPDIRECTSOUNDFXCHORUS8;
#define IID_IDirectSoundFXChorus8           IID_IDirectSoundFXChorus

DEFINE_GUID(IID_IDirectSoundFXFlanger,      0x903e9878,0x2c92,0x4072,0x9b,0x2c,0xea,0x68,0xf5,0x39,0x67,0x83);
#define IDirectSoundFXFlanger8              IDirectSoundFXFlanger
typedef struct IDirectSoundFXFlanger8       *LPDIRECTSOUNDFXFLANGER8;
#define IID_IDirectSoundFXFlanger8          IID_IDirectSoundFXFlanger

DEFINE_GUID(IID_IDirectSoundFXEcho,         0x8bd28edf,0x50db,0x4e92,0xa2,0xbd,0x44,0x54,0x88, 0xd1,0xed,0x42);
#define IDirectSoundFXEcho8                 IDirectSoundFXEcho
typedef struct IDirectSoundFXEcho8          *LPDIRECTSOUNDFXECHO8;
#define IID_IDirectSoundFXEcho8             IID_IDirectSoundFXEcho

DEFINE_GUID(IID_IDirectSoundFXDistortion,   0x8ecf4326,0x455f,0x4d8b,0xbd,0xa9,0x8d,0x5d,0x3e,0x9e,0x3e,0x0b);
#define IDirectSoundFXDistortion8           IDirectSoundFXDistortion
typedef struct IDirectSoundFXDistortion8    *LPDIRECTSOUNDFXDISTORTION8;
#define IID_IDirectSoundFXDistortion8       IID_IDirectSoundFXDistortion

DEFINE_GUID(IID_IDirectSoundFXCompressor,   0x4bbd1154,0x62f6,0x4e2c,0xa1,0x5c,0xd3,0xb6,0xc4,0x17,0xf7,0xa0);
#define IDirectSoundFXCompressor8           IDirectSoundFXCompressor
typedef struct IDirectSoundFXCompressor8    *LPDIRECTSOUNDFXCOMPRESSOR8;
#define IID_IDirectSoundFXCompressor8       IID_IDirectSoundFXCompressor

DEFINE_GUID(IID_IDirectSoundFXParamEq,      0xc03ca9fe,0xfe90,0x4204,0x80,0x78,0x82,0x33,0x4c,0xd1,0x77,0xda);
#define IDirectSoundFXParamEq8              IDirectSoundFXParamEq
typedef struct IDirectSoundFXParamEq8       *LPDIRECTSOUNDFXPARAMEQ8;
#define IID_IDirectSoundFXParamEq8          IID_IDirectSoundFXParamEq

DEFINE_GUID(IID_IDirectSoundFXWavesReverb,  0x46858c3a,0x0dc6,0x45e3,0xb7,0x60,0xd4,0xee,0xf1,0x6c,0xb3,0x25);
#define IDirectSoundFXWavesReverb8          IDirectSoundFXWavesReverb
typedef struct IDirectSoundFXWavesReverb8   *LPDIRECTSOUNDFXWAVESREVERB8;
#define IID_IDirectSoundFXWavesReverb8      IID_IDirectSoundFXWavesReverb

#define	_FACDS		0x878
#define	MAKE_DSHRESULT(code)		MAKE_HRESULT(1,_FACDS,code)

#define DS_OK				0
#define DS_NO_VIRTUALIZATION            MAKE_HRESULT(0, _FACDS, 10)
#define DS_INCOMPLETE                   MAKE_HRESULT(0, _FACDS, 20)
#define DSERR_ALLOCATED			MAKE_DSHRESULT(10)
#define DSERR_CONTROLUNAVAIL		MAKE_DSHRESULT(30)
#define DSERR_INVALIDPARAM		E_INVALIDARG
#define DSERR_INVALIDCALL		MAKE_DSHRESULT(50)
#define DSERR_GENERIC			E_FAIL
#define DSERR_PRIOLEVELNEEDED		MAKE_DSHRESULT(70)
#define DSERR_OUTOFMEMORY		E_OUTOFMEMORY
#define DSERR_BADFORMAT			MAKE_DSHRESULT(100)
#define DSERR_UNSUPPORTED		E_NOTIMPL
#define DSERR_NODRIVER			MAKE_DSHRESULT(120)
#define DSERR_ALREADYINITIALIZED	MAKE_DSHRESULT(130)
#define DSERR_NOAGGREGATION		CLASS_E_NOAGGREGATION
#define DSERR_BUFFERLOST		MAKE_DSHRESULT(150)
#define DSERR_OTHERAPPHASPRIO		MAKE_DSHRESULT(160)
#define DSERR_UNINITIALIZED		MAKE_DSHRESULT(170)
#define DSERR_NOINTERFACE               E_NOINTERFACE
#define DSERR_ACCESSDENIED              E_ACCESSDENIED
#define DSERR_BUFFERTOOSMALL            MAKE_DSHRESULT(180)
#define DSERR_DS8_REQUIRED              MAKE_DSHRESULT(190)
#define DSERR_SENDLOOP                  MAKE_DSHRESULT(200)
#define DSERR_BADSENDBUFFERGUID         MAKE_DSHRESULT(210)
#define DSERR_FXUNAVAILABLE             MAKE_DSHRESULT(220)
#define DSERR_OBJECTNOTFOUND            MAKE_DSHRESULT(4449)

#define DSCAPS_PRIMARYMONO          0x00000001
#define DSCAPS_PRIMARYSTEREO        0x00000002
#define DSCAPS_PRIMARY8BIT          0x00000004
#define DSCAPS_PRIMARY16BIT         0x00000008
#define DSCAPS_CONTINUOUSRATE       0x00000010
#define DSCAPS_EMULDRIVER           0x00000020
#define DSCAPS_CERTIFIED            0x00000040
#define DSCAPS_SECONDARYMONO        0x00000100
#define DSCAPS_SECONDARYSTEREO      0x00000200
#define DSCAPS_SECONDARY8BIT        0x00000400
#define DSCAPS_SECONDARY16BIT       0x00000800

#define	DSSCL_NORMAL		1
#define	DSSCL_PRIORITY		2
#define	DSSCL_EXCLUSIVE		3
#define	DSSCL_WRITEPRIMARY	4

typedef struct _DSCAPS
{
    DWORD	dwSize;
    DWORD	dwFlags;
    DWORD	dwMinSecondarySampleRate;
    DWORD	dwMaxSecondarySampleRate;
    DWORD	dwPrimaryBuffers;
    DWORD	dwMaxHwMixingAllBuffers;
    DWORD	dwMaxHwMixingStaticBuffers;
    DWORD	dwMaxHwMixingStreamingBuffers;
    DWORD	dwFreeHwMixingAllBuffers;
    DWORD	dwFreeHwMixingStaticBuffers;
    DWORD	dwFreeHwMixingStreamingBuffers;
    DWORD	dwMaxHw3DAllBuffers;
    DWORD	dwMaxHw3DStaticBuffers;
    DWORD	dwMaxHw3DStreamingBuffers;
    DWORD	dwFreeHw3DAllBuffers;
    DWORD	dwFreeHw3DStaticBuffers;
    DWORD	dwFreeHw3DStreamingBuffers;
    DWORD	dwTotalHwMemBytes;
    DWORD	dwFreeHwMemBytes;
    DWORD	dwMaxContigFreeHwMemBytes;
    DWORD	dwUnlockTransferRateHwBuffers;
    DWORD	dwPlayCpuOverheadSwBuffers;
    DWORD	dwReserved1;
    DWORD	dwReserved2;
} DSCAPS,*LPDSCAPS;
typedef const DSCAPS *LPCDSCAPS;

#define DSBPLAY_LOOPING             0x00000001
#define DSBPLAY_LOCHARDWARE         0x00000002
#define DSBPLAY_LOCSOFTWARE         0x00000004
#define DSBPLAY_TERMINATEBY_TIME    0x00000008
#define DSBPLAY_TERMINATEBY_DISTANCE    0x000000010
#define DSBPLAY_TERMINATEBY_PRIORITY    0x000000020

#define DSBSTATUS_PLAYING           0x00000001
#define DSBSTATUS_BUFFERLOST        0x00000002
#define DSBSTATUS_LOOPING           0x00000004
#define DSBSTATUS_LOCHARDWARE       0x00000008
#define DSBSTATUS_LOCSOFTWARE       0x00000010
#define DSBSTATUS_TERMINATED        0x00000020

#define DSBLOCK_FROMWRITECURSOR     0x00000001
#define DSBLOCK_ENTIREBUFFER        0x00000002

#define DSBCAPS_PRIMARYBUFFER       0x00000001
#define DSBCAPS_STATIC              0x00000002
#define DSBCAPS_LOCHARDWARE         0x00000004
#define DSBCAPS_LOCSOFTWARE         0x00000008
#define DSBCAPS_CTRL3D              0x00000010
#define DSBCAPS_CTRLFREQUENCY       0x00000020
#define DSBCAPS_CTRLPAN             0x00000040
#define DSBCAPS_CTRLVOLUME          0x00000080
#define DSBCAPS_CTRLDEFAULT         0x000000E0  /* Pan + volume + frequency. */
#define DSBCAPS_CTRLPOSITIONNOTIFY  0x00000100
#define DSBCAPS_CTRLFX              0x00000200
#define DSBCAPS_CTRLALL             0x000001F0  /* All control capabilities */
#define DSBCAPS_STICKYFOCUS         0x00004000
#define DSBCAPS_GLOBALFOCUS         0x00008000
#define DSBCAPS_GETCURRENTPOSITION2 0x00010000  /* More accurate play cursor under emulation*/
#define DSBCAPS_MUTE3DATMAXDISTANCE 0x00020000
#define DSBCAPS_LOCDEFER            0x00040000

#define DSBSIZE_MIN                 4
#define DSBSIZE_MAX                 0xFFFFFFF
#define DSBSIZE_FX_MIN		    150
#define DSBPAN_LEFT                 -10000
#define DSBPAN_CENTER               0
#define DSBPAN_RIGHT                 10000
#define DSBVOLUME_MAX                    0
#define DSBVOLUME_MIN               -10000
#define DSBFREQUENCY_MIN            100
#if (DIRECTSOUND_VERSION >= 0x0900)
#define DSBFREQUENCY_MAX            200000
#else
#define DSBFREQUENCY_MAX            100000
#endif
#define DSBFREQUENCY_ORIGINAL       0

#define DSBNOTIFICATIONS_MAX        100000U

typedef struct _DSBCAPS
{
    DWORD	dwSize;
    DWORD	dwFlags;
    DWORD	dwBufferBytes;
    DWORD	dwUnlockTransferRate;
    DWORD	dwPlayCpuOverhead;
} DSBCAPS,*LPDSBCAPS;
typedef const DSBCAPS *LPCDSBCAPS;

#define DSSCL_NORMAL                1
#define DSSCL_PRIORITY              2
#define DSSCL_EXCLUSIVE             3
#define DSSCL_WRITEPRIMARY          4

typedef struct _DSEFFECTDESC
{
    DWORD	dwSize;
    DWORD	dwFlags;
    GUID	guidDSFXClass;
    DWORD_PTR	dwReserved1;
    DWORD_PTR	dwReserved2;
} DSEFFECTDESC,*LPDSEFFECTDESC;
typedef const DSEFFECTDESC *LPCDSEFFECTDESC;

#define DSFX_LOCHARDWARE    0x00000001
#define DSFX_LOCSOFTWARE    0x00000002

enum
{
    DSFXR_PRESENT,
    DSFXR_LOCHARDWARE,
    DSFXR_LOCSOFTWARE,
    DSFXR_UNALLOCATED,
    DSFXR_FAILED,
    DSFXR_UNKNOWN,
    DSFXR_SENDLOOP
};

typedef struct _DSBUFFERDESC1
{
    DWORD		dwSize;
    DWORD		dwFlags;
    DWORD		dwBufferBytes;
    DWORD		dwReserved;
    LPWAVEFORMATEX	lpwfxFormat;
} DSBUFFERDESC1,*LPDSBUFFERDESC1;
typedef const DSBUFFERDESC1 *LPCDSBUFFERDESC1;

typedef struct _DSBUFFERDESC
{
    DWORD		dwSize;
    DWORD		dwFlags;
    DWORD		dwBufferBytes;
    DWORD		dwReserved;
    LPWAVEFORMATEX	lpwfxFormat;
#if (DIRECTSOUND_VERSION >= 0x0700)
    GUID		guid3DAlgorithm;
#endif /* DS7 */
} DSBUFFERDESC,*LPDSBUFFERDESC;
typedef const DSBUFFERDESC *LPCDSBUFFERDESC;

typedef struct _DSBPOSITIONNOTIFY
{
    DWORD	dwOffset;
    HANDLE	hEventNotify;
} DSBPOSITIONNOTIFY,*LPDSBPOSITIONNOTIFY;
typedef const DSBPOSITIONNOTIFY *LPCDSBPOSITIONNOTIFY;

#define DSSPEAKER_DIRECTOUT     0
#define DSSPEAKER_HEADPHONE     1
#define DSSPEAKER_MONO          2
#define DSSPEAKER_QUAD          3
#define DSSPEAKER_STEREO        4
#define DSSPEAKER_SURROUND      5
#define DSSPEAKER_5POINT1       6
#define DSSPEAKER_5POINT1_BACK  6
#define DSSPEAKER_7POINT1       7
#define DSSPEAKER_7POINT1_WIDE  7
#define DSSPEAKER_7POINT1_SURROUND  8
#define DSSPEAKER_5POINT1_SURROUND  9

#define DSSPEAKER_GEOMETRY_MIN      0x00000005  /* 5 degrees */
#define DSSPEAKER_GEOMETRY_NARROW   0x0000000A  /* 10 degrees */
#define DSSPEAKER_GEOMETRY_WIDE     0x00000014  /* 20 degrees */
#define DSSPEAKER_GEOMETRY_MAX      0x000000B4  /* 180 degrees */

#define DSSPEAKER_COMBINED(c, g)    ((DWORD)(((BYTE)(c)) | ((DWORD)((BYTE)(g))) << 16))
#define DSSPEAKER_CONFIG(a)         ((BYTE)(a))
#define DSSPEAKER_GEOMETRY(a)       ((BYTE)(((DWORD)(a) >> 16) & 0x00FF))

#define DS_CERTIFIED                0x00000000
#define DS_UNCERTIFIED              0x00000001

typedef struct _DSCEFFECTDESC
{
    DWORD       dwSize;
    DWORD       dwFlags;
    GUID        guidDSCFXClass;
    GUID        guidDSCFXInstance;
    DWORD       dwReserved1;
    DWORD       dwReserved2;
} DSCEFFECTDESC, *LPDSCEFFECTDESC;
typedef const DSCEFFECTDESC *LPCDSCEFFECTDESC;

#define DSCFX_LOCHARDWARE   0x00000001
#define DSCFX_LOCSOFTWARE   0x00000002

#define DSCFXR_LOCHARDWARE  0x00000010
#define DSCFXR_LOCSOFTWARE  0x00000020

typedef struct _DSCBUFFERDESC1
{
  DWORD           dwSize;
  DWORD           dwFlags;
  DWORD           dwBufferBytes;
  DWORD           dwReserved;
  LPWAVEFORMATEX  lpwfxFormat;
} DSCBUFFERDESC1, *LPDSCBUFFERDESC1;

typedef struct _DSCBUFFERDESC
{
  DWORD           dwSize;
  DWORD           dwFlags;
  DWORD           dwBufferBytes;
  DWORD           dwReserved;
  LPWAVEFORMATEX  lpwfxFormat;
#if (DIRECTSOUND_VERSION >= 0x0800)
  DWORD           dwFXCount;
  LPDSCEFFECTDESC lpDSCFXDesc;
#endif /* DS8 */
} DSCBUFFERDESC, *LPDSCBUFFERDESC;
typedef const DSCBUFFERDESC *LPCDSCBUFFERDESC;

typedef struct _DSCCAPS
{
  DWORD dwSize;
  DWORD dwFlags;
  DWORD dwFormats;
  DWORD dwChannels;
} DSCCAPS, *LPDSCCAPS;
typedef const DSCCAPS *LPCDSCCAPS;

typedef struct _DSCBCAPS
{
  DWORD dwSize;
  DWORD dwFlags;
  DWORD dwBufferBytes;
  DWORD dwReserved;
} DSCBCAPS, *LPDSCBCAPS;
typedef const DSCBCAPS *LPCDSCBCAPS;

typedef struct _DSFXI3DL2Reverb
{
  LONG  lRoom;
  LONG  lRoomHF;
  FLOAT flRoomRolloffFactor;
  FLOAT flDecayTime;
  FLOAT flDecayHFRatio;
  LONG  lReflections;
  FLOAT flReflectionsDelay;
  LONG  lReverb;
  FLOAT flReverbDelay;
  FLOAT flDiffusion;
  FLOAT flDensity;
  FLOAT flHFReference;
} DSFXI3DL2Reverb, *LPDSFXI3DL2Reverb;

#define DSFX_I3DL2REVERB_DECAYTIME_DEFAULT              1.49f
#define DSFX_I3DL2REVERB_DECAYTIME_MIN                  0.1f
#define DSFX_I3DL2REVERB_DECAYTIME_MAX                 20.0f
#define DSFX_I3DL2REVERB_DECAYHFRATIO_DEFAULT           0.83f
#define DSFX_I3DL2REVERB_DECAYHFRATIO_MIN               0.1f
#define DSFX_I3DL2REVERB_DECAYHFRATIO_MAX               2.0f
#define DSFX_I3DL2REVERB_DENSITY_DEFAULT             100.0f
#define DSFX_I3DL2REVERB_DENSITY_MIN                   0.0f
#define DSFX_I3DL2REVERB_DENSITY_MAX                 100.0f
#define DSFX_I3DL2REVERB_DIFFUSION_DEFAULT           100.0f
#define DSFX_I3DL2REVERB_DIFFUSION_MIN                 0.0f
#define DSFX_I3DL2REVERB_DIFFUSION_MAX               100.0f
#define DSFX_I3DL2REVERB_HFREFERENCE_DEFAULT        5000.0f
#define DSFX_I3DL2REVERB_HFREFERENCE_MIN              20.0f
#define DSFX_I3DL2REVERB_HFREFERENCE_MAX           20000.0f
#define DSFX_I3DL2REVERB_QUALITY_DEFAULT               2
#define DSFX_I3DL2REVERB_QUALITY_MIN                   0
#define DSFX_I3DL2REVERB_QUALITY_MAX                   3
#define DSFX_I3DL2REVERB_REFLECTIONS_DEFAULT     (-2602)
#define DSFX_I3DL2REVERB_REFLECTIONS_MIN        (-10000)
#define DSFX_I3DL2REVERB_REFLECTIONS_MAX            1000
#define DSFX_I3DL2REVERB_REFLECTIONSDELAY_DEFAULT      0.007f
#define DSFX_I3DL2REVERB_REFLECTIONSDELAY_MIN          0.0f
#define DSFX_I3DL2REVERB_REFLECTIONSDELAY_MAX          0.3f
#define DSFX_I3DL2REVERB_REVERB_MIN             (-10000)
#define DSFX_I3DL2REVERB_REVERB_MAX                 2000
#define DSFX_I3DL2REVERB_REVERB_DEFAULT              200
#define DSFX_I3DL2REVERB_REVERBDELAY_MIN               0.0f
#define DSFX_I3DL2REVERB_REVERBDELAY_MAX               0.1f
#define DSFX_I3DL2REVERB_REVERBDELAY_DEFAULT           0.011f
#define DSFX_I3DL2REVERB_ROOM_DEFAULT            (-1000)
#define DSFX_I3DL2REVERB_ROOM_MIN               (-10000)
#define DSFX_I3DL2REVERB_ROOM_MAX                      0
#define DSFX_I3DL2REVERB_ROOMHF_MIN             (-10000)
#define DSFX_I3DL2REVERB_ROOMHF_MAX                    0
#define DSFX_I3DL2REVERB_ROOMHF_DEFAULT           (-100)
#define DSFX_I3DL2REVERB_ROOMROLLOFFFACTOR_MIN         0.0f
#define DSFX_I3DL2REVERB_ROOMROLLOFFFACTOR_MAX        10.0f
#define DSFX_I3DL2REVERB_ROOMROLLOFFFACTOR_DEFAULT     0.0f

typedef const DSFXI3DL2Reverb *LPCDSFXI3DL2Reverb;

#define DSCCAPS_EMULDRIVER          DSCAPS_EMULDRIVER
#define DSCCAPS_CERTIFIED           DSCAPS_CERTIFIED
#define DSCCAPS_MULTIPLECAPTURE     0x00000001

#define DSCBCAPS_WAVEMAPPED         0x80000000
#define DSCBCAPS_CTRLFX             0x00000200

#define DSCBLOCK_ENTIREBUFFER       0x00000001
#define DSCBSTART_LOOPING           0x00000001
#define DSCBPN_OFFSET_STOP          0xffffffff

#define DSCBSTATUS_CAPTURING        0x00000001
#define DSCBSTATUS_LOOPING          0x00000002

#ifndef __LPCGUID_DEFINED__
#define __LPCGUID_DEFINED__
typedef const GUID *LPCGUID;
#endif

typedef WINBOOL (CALLBACK *LPDSENUMCALLBACKW)(LPGUID,LPCWSTR,LPCWSTR,LPVOID);
typedef WINBOOL (CALLBACK *LPDSENUMCALLBACKA)(LPGUID,LPCSTR,LPCSTR,LPVOID);
__MINGW_TYPEDEF_AW(LPDSENUMCALLBACK)

extern HRESULT WINAPI DirectSoundCreate(LPCGUID lpGUID,LPDIRECTSOUND *ppDS,LPUNKNOWN pUnkOuter);
extern HRESULT WINAPI DirectSoundEnumerateA(LPDSENUMCALLBACKA, LPVOID);
extern HRESULT WINAPI DirectSoundEnumerateW(LPDSENUMCALLBACKW, LPVOID);
#define DirectSoundEnumerate __MINGW_NAME_AW(DirectSoundEnumerate)
extern HRESULT WINAPI DirectSoundCaptureCreate(LPCGUID lpGUID, LPDIRECTSOUNDCAPTURE *ppDSC, LPUNKNOWN pUnkOuter);
extern HRESULT WINAPI DirectSoundCaptureEnumerateA(LPDSENUMCALLBACKA, LPVOID);
extern HRESULT WINAPI DirectSoundCaptureEnumerateW(LPDSENUMCALLBACKW, LPVOID);
#define DirectSoundCaptureEnumerate __MINGW_NAME_AW(DirectSoundCaptureEnumerate)

extern HRESULT WINAPI DirectSoundCreate8(LPCGUID lpGUID,LPDIRECTSOUND8 *ppDS8,LPUNKNOWN pUnkOuter);
extern HRESULT WINAPI DirectSoundCaptureCreate8(LPCGUID lpGUID, LPDIRECTSOUNDCAPTURE8 *ppDSC8, LPUNKNOWN pUnkOuter);
extern HRESULT WINAPI DirectSoundFullDuplexCreate(LPCGUID pcGuidCaptureDevice, LPCGUID pcGuidRenderDevice,
    LPCDSCBUFFERDESC pcDSCBufferDesc, LPCDSBUFFERDESC pcDSBufferDesc, HWND hWnd, DWORD dwLevel,
    LPDIRECTSOUNDFULLDUPLEX *ppDSFD, LPDIRECTSOUNDCAPTUREBUFFER8 *ppDSCBuffer8, LPDIRECTSOUNDBUFFER8 *ppDSBuffer8, LPUNKNOWN pUnkOuter);
#define DirectSoundFullDuplexCreate8 DirectSoundFullDuplexCreate
extern HRESULT WINAPI GetDeviceID(LPCGUID lpGuidSrc, LPGUID lpGuidDest);


/*****************************************************************************
 * IDirectSound interface
 */
#define INTERFACE IDirectSound
DECLARE_INTERFACE_(IDirectSound,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSound methods ***/
    STDMETHOD(CreateSoundBuffer)(THIS_ LPCDSBUFFERDESC lpcDSBufferDesc, LPLPDIRECTSOUNDBUFFER lplpDirectSoundBuffer, IUnknown *pUnkOuter) PURE;
    STDMETHOD(GetCaps)(THIS_ LPDSCAPS lpDSCaps) PURE;
    STDMETHOD(DuplicateSoundBuffer)(THIS_ LPDIRECTSOUNDBUFFER lpDsbOriginal, LPLPDIRECTSOUNDBUFFER lplpDsbDuplicate) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwLevel) PURE;
    STDMETHOD(Compact)(THIS) PURE;
    STDMETHOD(GetSpeakerConfig)(THIS_ LPDWORD lpdwSpeakerConfig) PURE;
    STDMETHOD(SetSpeakerConfig)(THIS_ DWORD dwSpeakerConfig) PURE;
    STDMETHOD(Initialize)(THIS_ LPCGUID lpcGuid) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSound_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSound_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSound_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectSound methods ***/
#define IDirectSound_CreateSoundBuffer(p,a,b,c)  (p)->lpVtbl->CreateSoundBuffer(p,a,b,c)
#define IDirectSound_GetCaps(p,a)                (p)->lpVtbl->GetCaps(p,a)
#define IDirectSound_DuplicateSoundBuffer(p,a,b) (p)->lpVtbl->DuplicateSoundBuffer(p,a,b)
#define IDirectSound_SetCooperativeLevel(p,a,b)  (p)->lpVtbl->SetCooperativeLevel(p,a,b)
#define IDirectSound_Compact(p)                  (p)->lpVtbl->Compact(p)
#define IDirectSound_GetSpeakerConfig(p,a)       (p)->lpVtbl->GetSpeakerConfig(p,a)
#define IDirectSound_SetSpeakerConfig(p,a)       (p)->lpVtbl->SetSpeakerConfig(p,a)
#define IDirectSound_Initialize(p,a)             (p)->lpVtbl->Initialize(p,a)
#else
/*** IUnknown methods ***/
#define IDirectSound_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectSound_AddRef(p)             (p)->AddRef()
#define IDirectSound_Release(p)            (p)->Release()
/*** IDirectSound methods ***/
#define IDirectSound_CreateSoundBuffer(p,a,b,c)  (p)->CreateSoundBuffer(a,b,c)
#define IDirectSound_GetCaps(p,a)                (p)->GetCaps(a)
#define IDirectSound_DuplicateSoundBuffer(p,a,b) (p)->DuplicateSoundBuffer(a,b)
#define IDirectSound_SetCooperativeLevel(p,a,b)  (p)->SetCooperativeLevel(a,b)
#define IDirectSound_Compact(p)                  (p)->Compact()
#define IDirectSound_GetSpeakerConfig(p,a)       (p)->GetSpeakerConfig(a)
#define IDirectSound_SetSpeakerConfig(p,a)       (p)->SetSpeakerConfig(a)
#define IDirectSound_Initialize(p,a)             (p)->Initialize(a)
#endif


/*****************************************************************************
 * IDirectSound8 interface
 */
#define INTERFACE IDirectSound8
DECLARE_INTERFACE_(IDirectSound8,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSound8 methods ***/
    STDMETHOD(CreateSoundBuffer)(THIS_ LPCDSBUFFERDESC lpcDSBufferDesc, LPLPDIRECTSOUNDBUFFER lplpDirectSoundBuffer, IUnknown *pUnkOuter) PURE;
    STDMETHOD(GetCaps)(THIS_ LPDSCAPS lpDSCaps) PURE;
    STDMETHOD(DuplicateSoundBuffer)(THIS_ LPDIRECTSOUNDBUFFER lpDsbOriginal, LPLPDIRECTSOUNDBUFFER lplpDsbDuplicate) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwLevel) PURE;
    STDMETHOD(Compact)(THIS) PURE;
    STDMETHOD(GetSpeakerConfig)(THIS_ LPDWORD lpdwSpeakerConfig) PURE;
    STDMETHOD(SetSpeakerConfig)(THIS_ DWORD dwSpeakerConfig) PURE;
    STDMETHOD(Initialize)(THIS_ LPCGUID lpcGuid) PURE;
    STDMETHOD(VerifyCertification)(THIS_ LPDWORD pdwCertified) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSound8_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSound8_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSound8_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectSound methods ***/
#define IDirectSound8_CreateSoundBuffer(p,a,b,c)  (p)->lpVtbl->CreateSoundBuffer(p,a,b,c)
#define IDirectSound8_GetCaps(p,a)                (p)->lpVtbl->GetCaps(p,a)
#define IDirectSound8_DuplicateSoundBuffer(p,a,b) (p)->lpVtbl->DuplicateSoundBuffer(p,a,b)
#define IDirectSound8_SetCooperativeLevel(p,a,b)  (p)->lpVtbl->SetCooperativeLevel(p,a,b)
#define IDirectSound8_Compact(p)                  (p)->lpVtbl->Compact(p)
#define IDirectSound8_GetSpeakerConfig(p,a)       (p)->lpVtbl->GetSpeakerConfig(p,a)
#define IDirectSound8_SetSpeakerConfig(p,a)       (p)->lpVtbl->SetSpeakerConfig(p,a)
#define IDirectSound8_Initialize(p,a)             (p)->lpVtbl->Initialize(p,a)
/*** IDirectSound8 methods ***/
#define IDirectSound8_VerifyCertification(p,a)    (p)->lpVtbl->VerifyCertification(p,a)
#else
/*** IUnknown methods ***/
#define IDirectSound8_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectSound8_AddRef(p)             (p)->AddRef()
#define IDirectSound8_Release(p)            (p)->Release()
/*** IDirectSound methods ***/
#define IDirectSound8_CreateSoundBuffer(p,a,b,c)  (p)->CreateSoundBuffer(a,b,c)
#define IDirectSound8_GetCaps(p,a)                (p)->GetCaps(a)
#define IDirectSound8_DuplicateSoundBuffer(p,a,b) (p)->DuplicateSoundBuffer(a,b)
#define IDirectSound8_SetCooperativeLevel(p,a,b)  (p)->SetCooperativeLevel(a,b)
#define IDirectSound8_Compact(p)                  (p)->Compact()
#define IDirectSound8_GetSpeakerConfig(p,a)       (p)->GetSpeakerConfig(a)
#define IDirectSound8_SetSpeakerConfig(p,a)       (p)->SetSpeakerConfig(a)
#define IDirectSound8_Initialize(p,a)             (p)->Initialize(a)
/*** IDirectSound8 methods ***/
#define IDirectSound8_VerifyCertification(p,a)    (p)->VerifyCertification(a)
#endif


/*****************************************************************************
 * IDirectSoundBuffer interface
 */
#define INTERFACE IDirectSoundBuffer
DECLARE_INTERFACE_(IDirectSoundBuffer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSoundBuffer methods ***/
    STDMETHOD(GetCaps)(THIS_ LPDSBCAPS lpDSBufferCaps) PURE;
    STDMETHOD(GetCurrentPosition)(THIS_ LPDWORD lpdwCurrentPlayCursor, LPDWORD lpdwCurrentWriteCursor) PURE;
    STDMETHOD(GetFormat)(THIS_ LPWAVEFORMATEX lpwfxFormat, DWORD dwSizeAllocated, LPDWORD lpdwSizeWritten) PURE;
    STDMETHOD(GetVolume)(THIS_ LPLONG lplVolume) PURE;
    STDMETHOD(GetPan)(THIS_ LPLONG lplpan) PURE;
    STDMETHOD(GetFrequency)(THIS_ LPDWORD lpdwFrequency) PURE;
    STDMETHOD(GetStatus)(THIS_ LPDWORD lpdwStatus) PURE;
    STDMETHOD(Initialize)(THIS_ LPDIRECTSOUND lpDirectSound, LPCDSBUFFERDESC lpcDSBufferDesc) PURE;
    STDMETHOD(Lock)(THIS_ DWORD dwOffset, DWORD dwBytes, LPVOID *ppvAudioPtr1, LPDWORD pdwAudioBytes1, LPVOID *ppvAudioPtr2, LPDWORD pdwAudioBytes2, DWORD dwFlags) PURE;
    STDMETHOD(Play)(THIS_ DWORD dwReserved1, DWORD dwReserved2, DWORD dwFlags) PURE;
    STDMETHOD(SetCurrentPosition)(THIS_ DWORD dwNewPosition) PURE;
    STDMETHOD(SetFormat)(THIS_ LPCWAVEFORMATEX lpcfxFormat) PURE;
    STDMETHOD(SetVolume)(THIS_ LONG lVolume) PURE;
    STDMETHOD(SetPan)(THIS_ LONG lPan) PURE;
    STDMETHOD(SetFrequency)(THIS_ DWORD dwFrequency) PURE;
    STDMETHOD(Stop)(THIS) PURE;
    STDMETHOD(Unlock)(THIS_ LPVOID pvAudioPtr1, DWORD dwAudioBytes1, LPVOID pvAudioPtr2, DWORD dwAudioPtr2) PURE;
    STDMETHOD(Restore)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSoundBuffer_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundBuffer_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundBuffer_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectSoundBuffer methods ***/
#define IDirectSoundBuffer_GetCaps(p,a)                (p)->lpVtbl->GetCaps(p,a)
#define IDirectSoundBuffer_GetCurrentPosition(p,a,b)   (p)->lpVtbl->GetCurrentPosition(p,a,b)
#define IDirectSoundBuffer_GetFormat(p,a,b,c)          (p)->lpVtbl->GetFormat(p,a,b,c)
#define IDirectSoundBuffer_GetVolume(p,a)              (p)->lpVtbl->GetVolume(p,a)
#define IDirectSoundBuffer_GetPan(p,a)                 (p)->lpVtbl->GetPan(p,a)
#define IDirectSoundBuffer_GetFrequency(p,a)           (p)->lpVtbl->GetFrequency(p,a)
#define IDirectSoundBuffer_GetStatus(p,a)              (p)->lpVtbl->GetStatus(p,a)
#define IDirectSoundBuffer_Initialize(p,a,b)           (p)->lpVtbl->Initialize(p,a,b)
#define IDirectSoundBuffer_Lock(p,a,b,c,d,e,f,g)       (p)->lpVtbl->Lock(p,a,b,c,d,e,f,g)
#define IDirectSoundBuffer_Play(p,a,b,c)               (p)->lpVtbl->Play(p,a,b,c)
#define IDirectSoundBuffer_SetCurrentPosition(p,a)     (p)->lpVtbl->SetCurrentPosition(p,a)
#define IDirectSoundBuffer_SetFormat(p,a)              (p)->lpVtbl->SetFormat(p,a)
#define IDirectSoundBuffer_SetVolume(p,a)              (p)->lpVtbl->SetVolume(p,a)
#define IDirectSoundBuffer_SetPan(p,a)                 (p)->lpVtbl->SetPan(p,a)
#define IDirectSoundBuffer_SetFrequency(p,a)           (p)->lpVtbl->SetFrequency(p,a)
#define IDirectSoundBuffer_Stop(p)                     (p)->lpVtbl->Stop(p)
#define IDirectSoundBuffer_Unlock(p,a,b,c,d)           (p)->lpVtbl->Unlock(p,a,b,c,d)
#define IDirectSoundBuffer_Restore(p)                  (p)->lpVtbl->Restore(p)
#else
/*** IUnknown methods ***/
#define IDirectSoundBuffer_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectSoundBuffer_AddRef(p)             (p)->AddRef()
#define IDirectSoundBuffer_Release(p)            (p)->Release()
/*** IDirectSoundBuffer methods ***/
#define IDirectSoundBuffer_GetCaps(p,a)                (p)->GetCaps(a)
#define IDirectSoundBuffer_GetCurrentPosition(p,a,b)   (p)->GetCurrentPosition(a,b)
#define IDirectSoundBuffer_GetFormat(p,a,b,c)          (p)->GetFormat(a,b,c)
#define IDirectSoundBuffer_GetVolume(p,a)              (p)->GetVolume(a)
#define IDirectSoundBuffer_GetPan(p,a)                 (p)->GetPan(a)
#define IDirectSoundBuffer_GetFrequency(p,a)           (p)->GetFrequency(a)
#define IDirectSoundBuffer_GetStatus(p,a)              (p)->GetStatus(a)
#define IDirectSoundBuffer_Initialize(p,a,b)           (p)->Initialize(a,b)
#define IDirectSoundBuffer_Lock(p,a,b,c,d,e,f,g)       (p)->Lock(a,b,c,d,e,f,g)
#define IDirectSoundBuffer_Play(p,a,b,c)               (p)->Play(a,b,c)
#define IDirectSoundBuffer_SetCurrentPosition(p,a)     (p)->SetCurrentPosition(a)
#define IDirectSoundBuffer_SetFormat(p,a)              (p)->SetFormat(a)
#define IDirectSoundBuffer_SetVolume(p,a)              (p)->SetVolume(a)
#define IDirectSoundBuffer_SetPan(p,a)                 (p)->SetPan(a)
#define IDirectSoundBuffer_SetFrequency(p,a)           (p)->SetFrequency(a)
#define IDirectSoundBuffer_Stop(p)                     (p)->Stop()
#define IDirectSoundBuffer_Unlock(p,a,b,c,d)           (p)->Unlock(a,b,c,d)
#define IDirectSoundBuffer_Restore(p)                  (p)->Restore()
#endif


/*****************************************************************************
 * IDirectSoundBuffer8 interface
 */
#define INTERFACE IDirectSoundBuffer8
DECLARE_INTERFACE_(IDirectSoundBuffer8,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSoundBuffer8 methods ***/
    STDMETHOD(GetCaps)(THIS_ LPDSBCAPS lpDSBufferCaps) PURE;
    STDMETHOD(GetCurrentPosition)(THIS_ LPDWORD lpdwCurrentPlayCursor, LPDWORD lpdwCurrentWriteCursor) PURE;
    STDMETHOD(GetFormat)(THIS_ LPWAVEFORMATEX lpwfxFormat, DWORD dwSizeAllocated, LPDWORD lpdwSizeWritten) PURE;
    STDMETHOD(GetVolume)(THIS_ LPLONG lplVolume) PURE;
    STDMETHOD(GetPan)(THIS_ LPLONG lplpan) PURE;
    STDMETHOD(GetFrequency)(THIS_ LPDWORD lpdwFrequency) PURE;
    STDMETHOD(GetStatus)(THIS_ LPDWORD lpdwStatus) PURE;
    STDMETHOD(Initialize)(THIS_ LPDIRECTSOUND lpDirectSound, LPCDSBUFFERDESC lpcDSBufferDesc) PURE;
    STDMETHOD(Lock)(THIS_ DWORD dwOffset, DWORD dwBytes, LPVOID *ppvAudioPtr1, LPDWORD pdwAudioBytes1, LPVOID *ppvAudioPtr2, LPDWORD pdwAudioBytes2, DWORD dwFlags) PURE;
    STDMETHOD(Play)(THIS_ DWORD dwReserved1, DWORD dwReserved2, DWORD dwFlags) PURE;
    STDMETHOD(SetCurrentPosition)(THIS_ DWORD dwNewPosition) PURE;
    STDMETHOD(SetFormat)(THIS_ LPCWAVEFORMATEX lpcfxFormat) PURE;
    STDMETHOD(SetVolume)(THIS_ LONG lVolume) PURE;
    STDMETHOD(SetPan)(THIS_ LONG lPan) PURE;
    STDMETHOD(SetFrequency)(THIS_ DWORD dwFrequency) PURE;
    STDMETHOD(Stop)(THIS) PURE;
    STDMETHOD(Unlock)(THIS_ LPVOID pvAudioPtr1, DWORD dwAudioBytes1, LPVOID pvAudioPtr2, DWORD dwAudioPtr2) PURE;
    STDMETHOD(Restore)(THIS) PURE;
    STDMETHOD(SetFX)(THIS_ DWORD dwEffectsCount, LPDSEFFECTDESC pDSFXDesc, LPDWORD pdwResultCodes) PURE;
    STDMETHOD(AcquireResources)(THIS_ DWORD dwFlags, DWORD dwEffectsCount, LPDWORD pdwResultCodes) PURE;
    STDMETHOD(GetObjectInPath)(THIS_ REFGUID rguidObject, DWORD dwIndex, REFGUID rguidInterface, LPVOID *ppObject) PURE;
};
#undef INTERFACE

DEFINE_GUID(GUID_All_Objects, 0xaa114de5, 0xc262, 0x4169, 0xa1, 0xc8, 0x23, 0xd6, 0x98, 0xcc, 0x73, 0xb5);

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSoundBuffer8_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundBuffer8_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundBuffer8_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectSoundBuffer methods ***/
#define IDirectSoundBuffer8_GetCaps(p,a)                (p)->lpVtbl->GetCaps(p,a)
#define IDirectSoundBuffer8_GetCurrentPosition(p,a,b)   (p)->lpVtbl->GetCurrentPosition(p,a,b)
#define IDirectSoundBuffer8_GetFormat(p,a,b,c)          (p)->lpVtbl->GetFormat(p,a,b,c)
#define IDirectSoundBuffer8_GetVolume(p,a)              (p)->lpVtbl->GetVolume(p,a)
#define IDirectSoundBuffer8_GetPan(p,a)                 (p)->lpVtbl->GetPan(p,a)
#define IDirectSoundBuffer8_GetFrequency(p,a)           (p)->lpVtbl->GetFrequency(p,a)
#define IDirectSoundBuffer8_GetStatus(p,a)              (p)->lpVtbl->GetStatus(p,a)
#define IDirectSoundBuffer8_Initialize(p,a,b)           (p)->lpVtbl->Initialize(p,a,b)
#define IDirectSoundBuffer8_Lock(p,a,b,c,d,e,f,g)       (p)->lpVtbl->Lock(p,a,b,c,d,e,f,g)
#define IDirectSoundBuffer8_Play(p,a,b,c)               (p)->lpVtbl->Play(p,a,b,c)
#define IDirectSoundBuffer8_SetCurrentPosition(p,a)     (p)->lpVtbl->SetCurrentPosition(p,a)
#define IDirectSoundBuffer8_SetFormat(p,a)              (p)->lpVtbl->SetFormat(p,a)
#define IDirectSoundBuffer8_SetVolume(p,a)              (p)->lpVtbl->SetVolume(p,a)
#define IDirectSoundBuffer8_SetPan(p,a)                 (p)->lpVtbl->SetPan(p,a)
#define IDirectSoundBuffer8_SetFrequency(p,a)           (p)->lpVtbl->SetFrequency(p,a)
#define IDirectSoundBuffer8_Stop(p)                     (p)->lpVtbl->Stop(p)
#define IDirectSoundBuffer8_Unlock(p,a,b,c,d)           (p)->lpVtbl->Unlock(p,a,b,c,d)
#define IDirectSoundBuffer8_Restore(p)                  (p)->lpVtbl->Restore(p)
/*** IDirectSoundBuffer8 methods ***/
#define IDirectSoundBuffer8_SetFX(p,a,b,c)              (p)->lpVtbl->SetFX(p,a,b,c)
#define IDirectSoundBuffer8_AcquireResources(p,a,b,c)   (p)->lpVtbl->AcquireResources(p,a,b,c)
#define IDirectSoundBuffer8_GetObjectInPath(p,a,b,c,d)  (p)->lpVtbl->GetObjectInPath(p,a,b,c,d)
#else
/*** IUnknown methods ***/
#define IDirectSoundBuffer8_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectSoundBuffer8_AddRef(p)             (p)->AddRef()
#define IDirectSoundBuffer8_Release(p)            (p)->Release()
/*** IDirectSoundBuffer methods ***/
#define IDirectSoundBuffer8_GetCaps(p,a)                (p)->GetCaps(a)
#define IDirectSoundBuffer8_GetCurrentPosition(p,a,b)   (p)->GetCurrentPosition(a,b)
#define IDirectSoundBuffer8_GetFormat(p,a,b,c)          (p)->GetFormat(a,b,c)
#define IDirectSoundBuffer8_GetVolume(p,a)              (p)->GetVolume(a)
#define IDirectSoundBuffer8_GetPan(p,a)                 (p)->GetPan(a)
#define IDirectSoundBuffer8_GetFrequency(p,a)           (p)->GetFrequency(a)
#define IDirectSoundBuffer8_GetStatus(p,a)              (p)->GetStatus(a)
#define IDirectSoundBuffer8_Initialize(p,a,b)           (p)->Initialize(a,b)
#define IDirectSoundBuffer8_Lock(p,a,b,c,d,e,f,g)       (p)->Lock(a,b,c,d,e,f,g)
#define IDirectSoundBuffer8_Play(p,a,b,c)               (p)->Play(a,b,c)
#define IDirectSoundBuffer8_SetCurrentPosition(p,a)     (p)->SetCurrentPosition(a)
#define IDirectSoundBuffer8_SetFormat(p,a)              (p)->SetFormat(a)
#define IDirectSoundBuffer8_SetVolume(p,a)              (p)->SetVolume(a)
#define IDirectSoundBuffer8_SetPan(p,a)                 (p)->SetPan(a)
#define IDirectSoundBuffer8_SetFrequency(p,a)           (p)->SetFrequency(a)
#define IDirectSoundBuffer8_Stop(p)                     (p)->Stop()
#define IDirectSoundBuffer8_Unlock(p,a,b,c,d)           (p)->Unlock(a,b,c,d)
#define IDirectSoundBuffer8_Restore(p)                  (p)->Restore()
/*** IDirectSoundBuffer8 methods ***/
#define IDirectSoundBuffer8_SetFX(p,a,b,c)              (p)->SetFX(a,b,c)
#define IDirectSoundBuffer8_AcquireResources(p,a,b,c)   (p)->AcquireResources(a,b,c)
#define IDirectSoundBuffer8_GetObjectInPath(p,a,b,c,d)  (p)->GetObjectInPath(a,b,c,d)
#endif


/*****************************************************************************
 * IDirectSoundCapture interface
 */
#define INTERFACE IDirectSoundCapture
DECLARE_INTERFACE_(IDirectSoundCapture,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSoundCapture methods ***/
    STDMETHOD(CreateCaptureBuffer)(THIS_ LPCDSCBUFFERDESC lpcDSCBufferDesc,LPDIRECTSOUNDCAPTUREBUFFER *lplpDSCaptureBuffer, LPUNKNOWN pUnk) PURE;
    STDMETHOD(GetCaps)(THIS_ LPDSCCAPS lpDSCCaps) PURE;
    STDMETHOD(Initialize)(THIS_ LPCGUID lpcGUID) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSoundCapture_QueryInterface(p,a,b)        (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundCapture_AddRef(p)                    (p)->lpVtbl->AddRef(p)
#define IDirectSoundCapture_Release(p)                   (p)->lpVtbl->Release(p)
/*** IDirectSoundCapture methods ***/
#define IDirectSoundCapture_CreateCaptureBuffer(p,a,b,c) (p)->lpVtbl->CreateCaptureBuffer(p,a,b,c)
#define IDirectSoundCapture_GetCaps(p,a)                 (p)->lpVtbl->GetCaps(p,a)
#define IDirectSoundCapture_Initialize(p,a)              (p)->lpVtbl->Initialize(p,a)
#else
/*** IUnknown methods ***/
#define IDirectSoundCapture_QueryInterface(p,a,b)        (p)->QueryInterface(a,b)
#define IDirectSoundCapture_AddRef(p)                    (p)->AddRef()
#define IDirectSoundCapture_Release(p)                   (p)->Release()
/*** IDirectSoundCapture methods ***/
#define IDirectSoundCapture_CreateCaptureBuffer(p,a,b,c) (p)->CreateCaptureBuffer(a,b,c)
#define IDirectSoundCapture_GetCaps(p,a)                 (p)->GetCaps(a)
#define IDirectSoundCapture_Initialize(p,a)              (p)->Initialize(a)
#endif

/*****************************************************************************
 * IDirectSoundCaptureBuffer interface
 */
#define INTERFACE IDirectSoundCaptureBuffer
DECLARE_INTERFACE_(IDirectSoundCaptureBuffer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSoundCaptureBuffer methods ***/
    STDMETHOD(GetCaps)(THIS_ LPDSCBCAPS lpDSCBCaps) PURE;
    STDMETHOD(GetCurrentPosition)(THIS_ LPDWORD lpdwCapturePosition,LPDWORD lpdwReadPosition) PURE;
    STDMETHOD(GetFormat)(THIS_ LPWAVEFORMATEX lpwfxFormat, DWORD dwSizeAllocated, LPDWORD lpdwSizeWritten) PURE;
    STDMETHOD(GetStatus)(THIS_ LPDWORD lpdwStatus) PURE;
    STDMETHOD(Initialize)(THIS_ LPDIRECTSOUNDCAPTURE lpDSC, LPCDSCBUFFERDESC lpcDSCBDesc) PURE;
    STDMETHOD(Lock)(THIS_ DWORD dwReadCusor, DWORD dwReadBytes, LPVOID *lplpvAudioPtr1, LPDWORD lpdwAudioBytes1, LPVOID *lplpvAudioPtr2, LPDWORD lpdwAudioBytes2, DWORD dwFlags) PURE;
    STDMETHOD(Start)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(Stop)(THIS) PURE;
    STDMETHOD(Unlock)(THIS_ LPVOID lpvAudioPtr1, DWORD dwAudioBytes1, LPVOID lpvAudioPtr2, DWORD dwAudioBytes2) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSoundCaptureBuffer_QueryInterface(p,a,b)     (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundCaptureBuffer_AddRef(p)                 (p)->lpVtbl->AddRef(p)
#define IDirectSoundCaptureBuffer_Release(p)                (p)->lpVtbl->Release(p)
/*** IDirectSoundCaptureBuffer methods ***/
#define IDirectSoundCaptureBuffer_GetCaps(p,a)              (p)->lpVtbl->GetCaps(p,a)
#define IDirectSoundCaptureBuffer_GetCurrentPosition(p,a,b) (p)->lpVtbl->GetCurrentPosition(p,a,b)
#define IDirectSoundCaptureBuffer_GetFormat(p,a,b,c)        (p)->lpVtbl->GetFormat(p,a,b,c)
#define IDirectSoundCaptureBuffer_GetStatus(p,a)            (p)->lpVtbl->GetStatus(p,a)
#define IDirectSoundCaptureBuffer_Initialize(p,a,b)         (p)->lpVtbl->Initialize(p,a,b)
#define IDirectSoundCaptureBuffer_Lock(p,a,b,c,d,e,f,g)     (p)->lpVtbl->Lock(p,a,b,c,d,e,f,g)
#define IDirectSoundCaptureBuffer_Start(p,a)                (p)->lpVtbl->Start(p,a)
#define IDirectSoundCaptureBuffer_Stop(p)                   (p)->lpVtbl->Stop(p)
#define IDirectSoundCaptureBuffer_Unlock(p,a,b,c,d)         (p)->lpVtbl->Unlock(p,a,b,c,d)
#else
/*** IUnknown methods ***/
#define IDirectSoundCaptureBuffer_QueryInterface(p,a,b)     (p)->QueryInterface(a,b)
#define IDirectSoundCaptureBuffer_AddRef(p)                 (p)->AddRef()
#define IDirectSoundCaptureBuffer_Release(p)                (p)->Release()
/*** IDirectSoundCaptureBuffer methods ***/
#define IDirectSoundCaptureBuffer_GetCaps(p,a)              (p)->GetCaps(a)
#define IDirectSoundCaptureBuffer_GetCurrentPosition(p,a,b) (p)->GetCurrentPosition(a,b)
#define IDirectSoundCaptureBuffer_GetFormat(p,a,b,c)        (p)->GetFormat(a,b,c)
#define IDirectSoundCaptureBuffer_GetStatus(p,a)            (p)->GetStatus(a)
#define IDirectSoundCaptureBuffer_Initialize(p,a,b)         (p)->Initialize(a,b)
#define IDirectSoundCaptureBuffer_Lock(p,a,b,c,d,e,f,g)     (p)->Lock(a,b,c,d,e,f,g)
#define IDirectSoundCaptureBuffer_Start(p,a)                (p)->Start(a)
#define IDirectSoundCaptureBuffer_Stop(p)                   (p)->Stop()
#define IDirectSoundCaptureBuffer_Unlock(p,a,b,c,d)         (p)->Unlock(a,b,c,d)
#endif

/*****************************************************************************
 * IDirectSoundCaptureBuffer8 interface
 */
#define INTERFACE IDirectSoundCaptureBuffer8
DECLARE_INTERFACE_(IDirectSoundCaptureBuffer8,IDirectSoundCaptureBuffer)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSoundCaptureBuffer methods ***/
    STDMETHOD(GetCaps)(THIS_ LPDSCBCAPS lpDSCBCaps) PURE;
    STDMETHOD(GetCurrentPosition)(THIS_ LPDWORD lpdwCapturePosition,LPDWORD lpdwReadPosition) PURE;
    STDMETHOD(GetFormat)(THIS_ LPWAVEFORMATEX lpwfxFormat, DWORD dwSizeAllocated, LPDWORD lpdwSizeWritten) PURE;
    STDMETHOD(GetStatus)(THIS_ LPDWORD lpdwStatus) PURE;
    STDMETHOD(Initialize)(THIS_ LPDIRECTSOUNDCAPTURE lpDSC, LPCDSCBUFFERDESC lpcDSCBDesc) PURE;
    STDMETHOD(Lock)(THIS_ DWORD dwReadCusor, DWORD dwReadBytes, LPVOID *lplpvAudioPtr1, LPDWORD lpdwAudioBytes1, LPVOID *lplpvAudioPtr2, LPDWORD lpdwAudioBytes2, DWORD dwFlags) PURE;
    STDMETHOD(Start)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(Stop)(THIS) PURE;
    STDMETHOD(Unlock)(THIS_ LPVOID lpvAudioPtr1, DWORD dwAudioBytes1, LPVOID lpvAudioPtr2, DWORD dwAudioBytes2) PURE;
    /*** IDirectSoundCaptureBuffer8 methods ***/
    STDMETHOD(GetObjectInPath)(THIS_ REFGUID rguidObject, DWORD dwIndex, REFGUID rguidInterface, LPVOID *ppObject) PURE;
    STDMETHOD(GetFXStatus)(THIS_ DWORD dwFXCount, LPDWORD pdwFXStatus) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSoundCaptureBuffer8_QueryInterface(p,a,b)      (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundCaptureBuffer8_AddRef(p)                  (p)->lpVtbl->AddRef(p)
#define IDirectSoundCaptureBuffer8_Release(p)                 (p)->lpVtbl->Release(p)
/*** IDirectSoundCaptureBuffer methods ***/
#define IDirectSoundCaptureBuffer8_GetCaps(p,a)               (p)->lpVtbl->GetCaps(p,a)
#define IDirectSoundCaptureBuffer8_GetCurrentPosition(p,a,b)  (p)->lpVtbl->GetCurrentPosition(p,a,b)
#define IDirectSoundCaptureBuffer8_GetFormat(p,a,b,c)         (p)->lpVtbl->GetFormat(p,a,b,c)
#define IDirectSoundCaptureBuffer8_GetStatus(p,a)             (p)->lpVtbl->GetStatus(p,a)
#define IDirectSoundCaptureBuffer8_Initialize(p,a,b)          (p)->lpVtbl->Initialize(p,a,b)
#define IDirectSoundCaptureBuffer8_Lock(p,a,b,c,d,e,f,g)      (p)->lpVtbl->Lock(p,a,b,c,d,e,f,g)
#define IDirectSoundCaptureBuffer8_Start(p,a)                 (p)->lpVtbl->Start(p,a)
#define IDirectSoundCaptureBuffer8_Stop(p)                    (p)->lpVtbl->Stop(p)
#define IDirectSoundCaptureBuffer8_Unlock(p,a,b,c,d)          (p)->lpVtbl->Unlock(p,a,b,c,d)
/*** IDirectSoundCaptureBuffer8 methods ***/
#define IDirectSoundCaptureBuffer8_GetObjectInPath(p,a,b,c,d) (p)->lpVtbl->GetObjectInPath(p,a,b,c,d)
#define IDirectSoundCaptureBuffer8_GetFXStatus(p,a,b)         (p)->lpVtbl->GetFXStatus(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirectSoundCaptureBuffer8_QueryInterface(p,a,b)      (p)->QueryInterface(a,b)
#define IDirectSoundCaptureBuffer8_AddRef(p)                  (p)->AddRef()
#define IDirectSoundCaptureBuffer8_Release(p)                 (p)->Release()
/*** IDirectSoundCaptureBuffer methods ***/
#define IDirectSoundCaptureBuffer8_GetCaps(p,a)               (p)->GetCaps(a)
#define IDirectSoundCaptureBuffer8_GetCurrentPosition(p,a,b)  (p)->GetCurrentPosition(a,b)
#define IDirectSoundCaptureBuffer8_GetFormat(p,a,b,c)         (p)->GetFormat(a,b,c)
#define IDirectSoundCaptureBuffer8_GetStatus(p,a)             (p)->GetStatus(a)
#define IDirectSoundCaptureBuffer8_Initialize(p,a,b)          (p)->Initialize(a,b)
#define IDirectSoundCaptureBuffer8_Lock(p,a,b,c,d,e,f,g)      (p)->Lock(a,b,c,d,e,f,g)
#define IDirectSoundCaptureBuffer8_Start(p,a)                 (p)->Start(a)
#define IDirectSoundCaptureBuffer8_Stop(p)                    (p)->Stop()
#define IDirectSoundCaptureBuffer8_Unlock(p,a,b,c,d)          (p)->Unlock(a,b,c,d)
/*** IDirectSoundCaptureBuffer8 methods ***/
#define IDirectSoundCaptureBuffer8_GetObjectInPath(p,a,b,c,d) (p)->GetObjectInPath(a,b,c,d)
#define IDirectSoundCaptureBuffer8_GetFXStatus(p,a,b)         (p)->GetFXStatus(a,b)
#endif

/*****************************************************************************
 * IDirectSoundNotify interface
 */
#define WINE_NOBUFFER                   0x80000000

#define DSBPN_OFFSETSTOP		-1

#define INTERFACE IDirectSoundNotify
DECLARE_INTERFACE_(IDirectSoundNotify,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSoundNotify methods ***/
    STDMETHOD(SetNotificationPositions)(THIS_ DWORD cPositionNotifies, LPCDSBPOSITIONNOTIFY lpcPositionNotifies) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSoundNotify_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundNotify_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundNotify_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectSoundNotify methods ***/
#define IDirectSoundNotify_SetNotificationPositions(p,a,b) (p)->lpVtbl->SetNotificationPositions(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirectSoundNotify_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectSoundNotify_AddRef(p)             (p)->AddRef()
#define IDirectSoundNotify_Release(p)            (p)->Release()
/*** IDirectSoundNotify methods ***/
#define IDirectSoundNotify_SetNotificationPositions(p,a,b) (p)->SetNotificationPositions(a,b)
#endif


/*****************************************************************************
 * IDirectSound3DListener interface
 */
#define DS3DMODE_NORMAL             0x00000000
#define DS3DMODE_HEADRELATIVE       0x00000001
#define DS3DMODE_DISABLE            0x00000002

#define DS3D_IMMEDIATE              0x00000000
#define DS3D_DEFERRED               0x00000001

#define DS3D_MINDISTANCEFACTOR      FLT_MIN
#define DS3D_MAXDISTANCEFACTOR      FLT_MAX
#define DS3D_DEFAULTDISTANCEFACTOR  1.0f

#define DS3D_MINROLLOFFFACTOR       0.0f
#define DS3D_MAXROLLOFFFACTOR       10.0f
#define DS3D_DEFAULTROLLOFFFACTOR   1.0f

#define DS3D_MINDOPPLERFACTOR       0.0f
#define DS3D_MAXDOPPLERFACTOR       10.0f
#define DS3D_DEFAULTDOPPLERFACTOR   1.0f

#define DS3D_DEFAULTMINDISTANCE     1.0f
#define DS3D_DEFAULTMAXDISTANCE     1000000000.0f

#define DS3D_MINCONEANGLE           0
#define DS3D_MAXCONEANGLE           360
#define DS3D_DEFAULTCONEANGLE       360

#define DS3D_DEFAULTCONEOUTSIDEVOLUME   DSBVOLUME_MAX

typedef struct _DS3DLISTENER {
	DWORD				dwSize;
	D3DVECTOR			vPosition;
	D3DVECTOR			vVelocity;
	D3DVECTOR			vOrientFront;
	D3DVECTOR			vOrientTop;
	D3DVALUE			flDistanceFactor;
	D3DVALUE			flRolloffFactor;
	D3DVALUE			flDopplerFactor;
} DS3DLISTENER, *LPDS3DLISTENER;

typedef const DS3DLISTENER *LPCDS3DLISTENER;

#define INTERFACE IDirectSound3DListener
DECLARE_INTERFACE_(IDirectSound3DListener,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSound3DListener methods ***/
    STDMETHOD(GetAllParameters)(THIS_ LPDS3DLISTENER lpListener) PURE;
    STDMETHOD(GetDistanceFactor)(THIS_ LPD3DVALUE lpflDistanceFactor) PURE;
    STDMETHOD(GetDopplerFactor)(THIS_ LPD3DVALUE lpflDopplerFactor) PURE;
    STDMETHOD(GetOrientation)(THIS_ LPD3DVECTOR lpvOrientFront, LPD3DVECTOR lpvOrientTop) PURE;
    STDMETHOD(GetPosition)(THIS_ LPD3DVECTOR lpvPosition) PURE;
    STDMETHOD(GetRolloffFactor)(THIS_ LPD3DVALUE lpflRolloffFactor) PURE;
    STDMETHOD(GetVelocity)(THIS_ LPD3DVECTOR lpvVelocity) PURE;
    STDMETHOD(SetAllParameters)(THIS_ LPCDS3DLISTENER lpcListener, DWORD dwApply) PURE;
    STDMETHOD(SetDistanceFactor)(THIS_ D3DVALUE flDistanceFactor, DWORD dwApply) PURE;
    STDMETHOD(SetDopplerFactor)(THIS_ D3DVALUE flDopplerFactor, DWORD dwApply) PURE;
    STDMETHOD(SetOrientation)(THIS_ D3DVALUE xFront, D3DVALUE yFront, D3DVALUE zFront, D3DVALUE xTop, D3DVALUE yTop, D3DVALUE zTop, DWORD dwApply) PURE;
    STDMETHOD(SetPosition)(THIS_ D3DVALUE x, D3DVALUE y, D3DVALUE z, DWORD dwApply) PURE;
    STDMETHOD(SetRolloffFactor)(THIS_ D3DVALUE flRolloffFactor, DWORD dwApply) PURE;
    STDMETHOD(SetVelocity)(THIS_ D3DVALUE x, D3DVALUE y, D3DVALUE z, DWORD dwApply) PURE;
    STDMETHOD(CommitDeferredSettings)(THIS) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSound3DListener_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSound3DListener_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSound3DListener_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectSound3DListener methods ***/
#define IDirectSound3DListener_GetAllParameters(p,a)           (p)->lpVtbl->GetAllParameters(p,a)
#define IDirectSound3DListener_GetDistanceFactor(p,a)          (p)->lpVtbl->GetDistanceFactor(p,a)
#define IDirectSound3DListener_GetDopplerFactor(p,a)           (p)->lpVtbl->GetDopplerFactor(p,a)
#define IDirectSound3DListener_GetOrientation(p,a,b)           (p)->lpVtbl->GetOrientation(p,a,b)
#define IDirectSound3DListener_GetPosition(p,a)                (p)->lpVtbl->GetPosition(p,a)
#define IDirectSound3DListener_GetRolloffFactor(p,a)           (p)->lpVtbl->GetRolloffFactor(p,a)
#define IDirectSound3DListener_GetVelocity(p,a)                (p)->lpVtbl->GetVelocity(p,a)
#define IDirectSound3DListener_SetAllParameters(p,a,b)         (p)->lpVtbl->SetAllParameters(p,a,b)
#define IDirectSound3DListener_SetDistanceFactor(p,a,b)        (p)->lpVtbl->SetDistanceFactor(p,a,b)
#define IDirectSound3DListener_SetDopplerFactor(p,a,b)         (p)->lpVtbl->SetDopplerFactor(p,a,b)
#define IDirectSound3DListener_SetOrientation(p,a,b,c,d,e,f,g) (p)->lpVtbl->SetOrientation(p,a,b,c,d,e,f,g)
#define IDirectSound3DListener_SetPosition(p,a,b,c,d)          (p)->lpVtbl->SetPosition(p,a,b,c,d)
#define IDirectSound3DListener_SetRolloffFactor(p,a,b)         (p)->lpVtbl->SetRolloffFactor(p,a,b)
#define IDirectSound3DListener_SetVelocity(p,a,b,c,d)          (p)->lpVtbl->SetVelocity(p,a,b,c,d)
#define IDirectSound3DListener_CommitDeferredSettings(p)       (p)->lpVtbl->CommitDeferredSettings(p)
#else
/*** IUnknown methods ***/
#define IDirectSound3DListener_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectSound3DListener_AddRef(p)             (p)->AddRef()
#define IDirectSound3DListener_Release(p)            (p)->Release()
/*** IDirectSound3DListener methods ***/
#define IDirectSound3DListener_GetAllParameters(p,a)           (p)->GetAllParameters(a)
#define IDirectSound3DListener_GetDistanceFactor(p,a)          (p)->GetDistanceFactor(a)
#define IDirectSound3DListener_GetDopplerFactor(p,a)           (p)->GetDopplerFactor(a)
#define IDirectSound3DListener_GetOrientation(p,a,b)           (p)->GetOrientation(a,b)
#define IDirectSound3DListener_GetPosition(p,a)                (p)->GetPosition(a)
#define IDirectSound3DListener_GetRolloffFactor(p,a)           (p)->GetRolloffFactor(a)
#define IDirectSound3DListener_GetVelocity(p,a)                (p)->GetVelocity(a)
#define IDirectSound3DListener_SetAllParameters(p,a,b)         (p)->SetAllParameters(a,b)
#define IDirectSound3DListener_SetDistanceFactor(p,a,b)        (p)->SetDistanceFactor(a,b)
#define IDirectSound3DListener_SetDopplerFactor(p,a,b)         (p)->SetDopplerFactor(a,b)
#define IDirectSound3DListener_SetOrientation(p,a,b,c,d,e,f,g) (p)->SetOrientation(a,b,c,d,e,f,g)
#define IDirectSound3DListener_SetPosition(p,a,b,c,d)          (p)->SetPosition(a,b,c,d)
#define IDirectSound3DListener_SetRolloffFactor(p,a,b)         (p)->SetRolloffFactor(a,b)
#define IDirectSound3DListener_SetVelocity(p,a,b,c,d)          (p)->SetVelocity(a,b,c,d)
#define IDirectSound3DListener_CommitDeferredSettings(p)       (p)->CommitDeferredSettings()
#endif

/*****************************************************************************
 * IDirectSound3DBuffer interface
 */
typedef struct  _DS3DBUFFER {
	DWORD				dwSize;
	D3DVECTOR			vPosition;
	D3DVECTOR			vVelocity;
	DWORD				dwInsideConeAngle;
	DWORD				dwOutsideConeAngle;
	D3DVECTOR			vConeOrientation;
	LONG				lConeOutsideVolume;
	D3DVALUE			flMinDistance;
	D3DVALUE			flMaxDistance;
	DWORD				dwMode;
} DS3DBUFFER, *LPDS3DBUFFER;

typedef const DS3DBUFFER *LPCDS3DBUFFER;

#define INTERFACE IDirectSound3DBuffer
DECLARE_INTERFACE_(IDirectSound3DBuffer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSound3DBuffer methods ***/
    STDMETHOD(GetAllParameters)(THIS_ LPDS3DBUFFER lpDs3dBuffer) PURE;
    STDMETHOD(GetConeAngles)(THIS_ LPDWORD lpdwInsideConeAngle, LPDWORD lpdwOutsideConeAngle) PURE;
    STDMETHOD(GetConeOrientation)(THIS_ LPD3DVECTOR lpvOrientation) PURE;
    STDMETHOD(GetConeOutsideVolume)(THIS_ LPLONG lplConeOutsideVolume) PURE;
    STDMETHOD(GetMaxDistance)(THIS_ LPD3DVALUE lpflMaxDistance) PURE;
    STDMETHOD(GetMinDistance)(THIS_ LPD3DVALUE lpflMinDistance) PURE;
    STDMETHOD(GetMode)(THIS_ LPDWORD lpwdMode) PURE;
    STDMETHOD(GetPosition)(THIS_ LPD3DVECTOR lpvPosition) PURE;
    STDMETHOD(GetVelocity)(THIS_ LPD3DVECTOR lpvVelocity) PURE;
    STDMETHOD(SetAllParameters)(THIS_ LPCDS3DBUFFER lpcDs3dBuffer, DWORD dwApply) PURE;
    STDMETHOD(SetConeAngles)(THIS_ DWORD dwInsideConeAngle, DWORD dwOutsideConeAngle, DWORD dwApply) PURE;
    STDMETHOD(SetConeOrientation)(THIS_ D3DVALUE x, D3DVALUE y, D3DVALUE z, DWORD dwApply) PURE;
    STDMETHOD(SetConeOutsideVolume)(THIS_ LONG lConeOutsideVolume, DWORD dwApply) PURE;
    STDMETHOD(SetMaxDistance)(THIS_ D3DVALUE flMaxDistance, DWORD dwApply) PURE;
    STDMETHOD(SetMinDistance)(THIS_ D3DVALUE flMinDistance, DWORD dwApply) PURE;
    STDMETHOD(SetMode)(THIS_ DWORD dwMode, DWORD dwApply) PURE;
    STDMETHOD(SetPosition)(THIS_ D3DVALUE x, D3DVALUE y, D3DVALUE z, DWORD dwApply) PURE;
    STDMETHOD(SetVelocity)(THIS_ D3DVALUE x, D3DVALUE y, D3DVALUE z, DWORD dwApply) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSound3DBuffer_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSound3DBuffer_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSound3DBuffer_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectSound3DBuffer methods ***/
#define IDirectSound3DBuffer_GetAllParameters(p,a)         (p)->lpVtbl->GetAllParameters(p,a)
#define IDirectSound3DBuffer_GetConeAngles(p,a,b)          (p)->lpVtbl->GetConeAngles(p,a,b)
#define IDirectSound3DBuffer_GetConeOrientation(p,a)       (p)->lpVtbl->GetConeOrientation(p,a)
#define IDirectSound3DBuffer_GetConeOutsideVolume(p,a)     (p)->lpVtbl->GetConeOutsideVolume(p,a)
#define IDirectSound3DBuffer_GetMaxDistance(p,a)           (p)->lpVtbl->GetMaxDistance(p,a)
#define IDirectSound3DBuffer_GetMinDistance(p,a)           (p)->lpVtbl->GetMinDistance(p,a)
#define IDirectSound3DBuffer_GetMode(p,a)                  (p)->lpVtbl->GetMode(p,a)
#define IDirectSound3DBuffer_GetPosition(p,a)              (p)->lpVtbl->GetPosition(p,a)
#define IDirectSound3DBuffer_GetVelocity(p,a)              (p)->lpVtbl->GetVelocity(p,a)
#define IDirectSound3DBuffer_SetAllParameters(p,a,b)       (p)->lpVtbl->SetAllParameters(p,a,b)
#define IDirectSound3DBuffer_SetConeAngles(p,a,b,c)        (p)->lpVtbl->SetConeAngles(p,a,b,c)
#define IDirectSound3DBuffer_SetConeOrientation(p,a,b,c,d) (p)->lpVtbl->SetConeOrientation(p,a,b,c,d)
#define IDirectSound3DBuffer_SetConeOutsideVolume(p,a,b)   (p)->lpVtbl->SetConeOutsideVolume(p,a,b)
#define IDirectSound3DBuffer_SetMaxDistance(p,a,b)         (p)->lpVtbl->SetMaxDistance(p,a,b)
#define IDirectSound3DBuffer_SetMinDistance(p,a,b)         (p)->lpVtbl->SetMinDistance(p,a,b)
#define IDirectSound3DBuffer_SetMode(p,a,b)                (p)->lpVtbl->SetMode(p,a,b)
#define IDirectSound3DBuffer_SetPosition(p,a,b,c,d)        (p)->lpVtbl->SetPosition(p,a,b,c,d)
#define IDirectSound3DBuffer_SetVelocity(p,a,b,c,d)        (p)->lpVtbl->SetVelocity(p,a,b,c,d)
#else
/*** IUnknown methods ***/
#define IDirectSound3DBuffer_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectSound3DBuffer_AddRef(p)             (p)->AddRef()
#define IDirectSound3DBuffer_Release(p)            (p)->Release()
/*** IDirectSound3DBuffer methods ***/
#define IDirectSound3DBuffer_GetAllParameters(p,a)         (p)->GetAllParameters(a)
#define IDirectSound3DBuffer_GetConeAngles(p,a,b)          (p)->GetConeAngles(a,b)
#define IDirectSound3DBuffer_GetConeOrientation(p,a)       (p)->GetConeOrientation(a)
#define IDirectSound3DBuffer_GetConeOutsideVolume(p,a)     (p)->GetConeOutsideVolume(a)
#define IDirectSound3DBuffer_GetMaxDistance(p,a)           (p)->GetMaxDistance(a)
#define IDirectSound3DBuffer_GetMinDistance(p,a)           (p)->GetMinDistance(a)
#define IDirectSound3DBuffer_GetMode(p,a)                  (p)->GetMode(a)
#define IDirectSound3DBuffer_GetPosition(p,a)              (p)->GetPosition(a)
#define IDirectSound3DBuffer_GetVelocity(p,a)              (p)->GetVelocity(a)
#define IDirectSound3DBuffer_SetAllParameters(p,a,b)       (p)->SetAllParameters(a,b)
#define IDirectSound3DBuffer_SetConeAngles(p,a,b,c)        (p)->SetConeAngles(a,b,c)
#define IDirectSound3DBuffer_SetConeOrientation(p,a,b,c,d) (p)->SetConeOrientation(a,b,c,d)
#define IDirectSound3DBuffer_SetConeOutsideVolume(p,a,b)   (p)->SetConeOutsideVolume(a,b)
#define IDirectSound3DBuffer_SetMaxDistance(p,a,b)         (p)->SetMaxDistance(a,b)
#define IDirectSound3DBuffer_SetMinDistance(p,a,b)         (p)->SetMinDistance(a,b)
#define IDirectSound3DBuffer_SetMode(p,a,b)                (p)->SetMode(a,b)
#define IDirectSound3DBuffer_SetPosition(p,a,b,c,d)        (p)->SetPosition(a,b,c,d)
#define IDirectSound3DBuffer_SetVelocity(p,a,b,c,d)        (p)->SetVelocity(a,b,c,d)
#endif

/*****************************************************************************
 * IKsPropertySet interface
 */
#ifndef _IKsPropertySet_
#define _IKsPropertySet_

typedef struct IKsPropertySet *LPKSPROPERTYSET;

DEFINE_GUID(IID_IKsPropertySet,0x31EFAC30,0x515C,0x11D0,0xA9,0xAA,0x00,0xAA,0x00,0x61,0xBE,0x93);

#define KSPROPERTY_SUPPORT_GET	1
#define KSPROPERTY_SUPPORT_SET	2

#define INTERFACE IKsPropertySet
DECLARE_INTERFACE_(IKsPropertySet,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IKsPropertySet methods ***/
    STDMETHOD(Get)(THIS_ REFGUID rgid,ULONG x1,LPVOID p1,ULONG x2,LPVOID p2,ULONG x3,ULONG *px4) PURE;
    STDMETHOD(Set)(THIS_ REFGUID rgid,ULONG x1,LPVOID p1,ULONG x2,LPVOID p2,ULONG x3) PURE;
    STDMETHOD(QuerySupport)(THIS_ REFGUID rgid,ULONG x1,ULONG *px2) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IKsPropertySet_QueryInterface(p,a,b)    (p)->lpVtbl->QueryInterface(p,a,b)
#define IKsPropertySet_AddRef(p)                (p)->lpVtbl->AddRef(p)
#define IKsPropertySet_Release(p)               (p)->lpVtbl->Release(p)
/*** IKsPropertySet methods ***/
#define IKsPropertySet_Get(p,a,b,c,d,e,f,g)     (p)->lpVtbl->Get(p,a,b,c,d,e,f,g)
#define IKsPropertySet_Set(p,a,b,c,d,e,f)       (p)->lpVtbl->Set(p,a,b,c,d,e,f)
#define IKsPropertySet_QuerySupport(p,a,b,c)    (p)->lpVtbl->QuerySupport(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IKsPropertySet_QueryInterface(p,a,b)    (p)->QueryInterface(a,b)
#define IKsPropertySet_AddRef(p)                (p)->AddRef()
#define IKsPropertySet_Release(p)               (p)->Release()
/*** IKsPropertySet methods ***/
#define IKsPropertySet_Get(p,a,b,c,d,e,f,g)     (p)->Get(a,b,c,d,e,f,g)
#define IKsPropertySet_Set(p,a,b,c,d,e,f)       (p)->Set(a,b,c,d,e,f)
#define IKsPropertySet_QuerySupport(p,a,b,c)    (p)->QuerySupport(a,b,c)
#endif

#endif /* _IKsPropertySet_ */

/*****************************************************************************
 * IDirectSoundFullDuplex interface
 */
#define INTERFACE IDirectSoundFullDuplex
DECLARE_INTERFACE_(IDirectSoundFullDuplex,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectSoundFullDuplex methods ***/
    STDMETHOD(Initialize)(THIS_ LPCGUID pCaptureGuid,LPCGUID pRendererGuid,LPCDSCBUFFERDESC lpDscBufferDesc,LPCDSBUFFERDESC lpDsBufferDesc,HWND hWnd,DWORD dwLevel,LPLPDIRECTSOUNDCAPTUREBUFFER8 lplpDirectSoundCaptureBuffer8,LPLPDIRECTSOUNDBUFFER8 lplpDirectSoundBuffer8) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectSoundFullDuplex_QueryInterface(p,a,b)    (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFullDuplex_AddRef(p)                (p)->lpVtbl->AddRef(p)
#define IDirectSoundFullDuplex_Release(p)               (p)->lpVtbl->Release(p)
/*** IDirectSoundFullDuplex methods ***/
#define IDirectSoundFullDuplex_Initialize(p,a,b,c,d,e,f,g,h)    (p)->lpVtbl->Initialize(p,a,b,c,d,e,f,g,h)
#else
/*** IUnknown methods ***/
#define IDirectSoundFullDuplex_QueryInterface(p,a,b)    (p)->QueryInterface(a,b)
#define IDirectSoundFullDuplex_AddRef(p)                (p)->AddRef()
#define IDirectSoundFullDuplex_Release(p)               (p)->Release()
/*** IDirectSoundFullDuplex methods ***/
#define IDirectSoundFullDuplex_Initialize(p,a,b,c,d,e,f,g,h)    (p)->Initialize(a,b,c,d,e,f,g,h)
#endif


/*****************************************************************************
 * IDirectSoundFXI3DL2Reverb interface
 */
#define INTERFACE IDirectSoundFXI3DL2Reverb
DECLARE_INTERFACE_(IDirectSoundFXI3DL2Reverb,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID, void**) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;

    /*** IDirectSoundFXI3DL2Reverb methods ***/
    STDMETHOD(SetAllParameters)(THIS_ LPCDSFXI3DL2Reverb reverb) PURE;
    STDMETHOD(GetAllParameters)(THIS_ LPDSFXI3DL2Reverb reverb) PURE;
    STDMETHOD(SetPreset)(THIS_ DWORD preset) PURE;
    STDMETHOD(GetPreset)(THIS_ DWORD *preset) PURE;
    STDMETHOD(SetQuality)(THIS_ LONG quality) PURE;
    STDMETHOD(GetQuality)(THIS_ LONG *quality) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IDirectSoundFXI3DL2Reverb_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFXI3DL2Reverb_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundFXI3DL2Reverb_Release(p)            (p)->lpVtbl->Release(p)
#define IDirectSoundFXI3DL2Reverb_SetAllParameters(p,a) (p)->lpVtbl->SetAllParameters(p,a)
#define IDirectSoundFXI3DL2Reverb_GetAllParameters(p,a) (p)->lpVtbl->GetAllParameters(p,a)
#define IDirectSoundFXI3DL2Reverb_SetPreset(p,a)        (p)->lpVtbl->SetPreset(p,a)
#define IDirectSoundFXI3DL2Reverb_GetPreset(p,a)        (p)->lpVtbl->GetPreset(p,a)
#else
#define IDirectSoundFXI3DL2Reverb_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectSoundFXI3DL2Reverb_AddRef(p)             (p)->AddRef()
#define IDirectSoundFXI3DL2Reverb_Release(p)            (p)->Release()
#define IDirectSoundFXI3DL2Reverb_SetAllParameters(p,a) (p)->SetAllParameters(a)
#define IDirectSoundFXI3DL2Reverb_GetAllParameters(p,a) (p)->GetAllParameters(a)
#define IDirectSoundFXI3DL2Reverb_SetPreset(p,a)        (p)->SetPreset(a)
#define IDirectSoundFXI3DL2Reverb_GetPreset(p,a)        (p)->GetPreset(a)
#endif

typedef struct _DSFXGargle
{
    DWORD       dwRateHz;
    DWORD       dwWaveShape;
} DSFXGargle, *LPDSFXGargle;

typedef const DSFXGargle *LPCDSFXGargle;

#define DSFXGARGLE_RATEHZ_MIN       1
#define DSFXGARGLE_RATEHZ_MAX    1000
#define DSFXGARGLE_WAVE_SQUARE      1
#define DSFXGARGLE_WAVE_TRIANGLE    0

#define INTERFACE IDirectSoundFXGargle
DECLARE_INTERFACE_(IDirectSoundFXGargle,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID, void**) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;

    /*** IDirectSoundFXGargle methods ***/
    STDMETHOD(SetAllParameters)(THIS_ const DSFXGargle *gargle) PURE;
    STDMETHOD(GetAllParameters)(THIS_ DSFXGargle *gargle) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IDirectSoundFXGargle_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFXGargle_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundFXGargle_Release(p)            (p)->lpVtbl->Release(p)
#define IDirectSoundFXGargle_SetAllParameters(p,a) (p)->lpVtbl->SetAllParameters(p,a)
#define IDirectSoundFXGargle_GetAllParameters(p,a) (p)->lpVtbl->GetAllParameters(p,a)
#else
#define IDirectSoundFXGargle_QueryInterface(p,a,b) (p)->QueryInterface(p,a,b)
#define IDirectSoundFXGargle_AddRef(p)             (p)->AddRef(p)
#define IDirectSoundFXGargle_Release(p)            (p)->Release(p)
#define IDirectSoundFXGargle_SetAllParameters(p,a) (p)->SetAllParameters(a)
#define IDirectSoundFXGargle_GetAllParameters(p,a) (p)->GetAllParameters(a)
#endif

typedef struct _DSFXChorus
{
    FLOAT fWetDryMix;
    FLOAT fDepth;
    FLOAT fFeedback;
    FLOAT fFrequency;
    LONG  lWaveform;
    FLOAT fDelay;
    LONG  lPhase;
} DSFXChorus, *LPDSFXChorus;

typedef const DSFXChorus *LPCDSFXChorus;

#define DSFXCHORUS_DEPTH_MIN       0.0f
#define DSFXCHORUS_DEPTH_MAX     100.0f
#define DSFXCHORUS_DELAY_MIN       0.0f
#define DSFXCHORUS_DELAY_MAX      20.0f
#define DSFXCHORUS_FEEDBACK_MIN  -99.0f
#define DSFXCHORUS_FEEDBACK_MAX   99.0f
#define DSFXCHORUS_FREQUENCY_MIN   0.0f
#define DSFXCHORUS_FREQUENCY_MAX  10.0f
#define DSFXCHORUS_PHASE_MIN       0
#define DSFXCHORUS_PHASE_MAX       4
#define DSFXCHORUS_PHASE_NEG_180   0
#define DSFXCHORUS_PHASE_NEG_90    1
#define DSFXCHORUS_PHASE_ZERO      2
#define DSFXCHORUS_PHASE_90        3
#define DSFXCHORUS_PHASE_180       4
#define DSFXCHORUS_WAVE_TRIANGLE   0
#define DSFXCHORUS_WAVE_SIN        1
#define DSFXCHORUS_WETDRYMIX_MIN   0.0f
#define DSFXCHORUS_WETDRYMIX_MAX 100.0f

#define INTERFACE IDirectSoundFXChorus
DECLARE_INTERFACE_(IDirectSoundFXChorus,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID, void**) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;

    /*** IDirectSoundFXChorus methods ***/
    STDMETHOD(SetAllParameters)(THIS_ const DSFXChorus *chorus) PURE;
    STDMETHOD(GetAllParameters)(THIS_ DSFXChorus *chorus) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IDirectSoundFXChorus_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFXChorus_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundFXChorus_Release(p)            (p)->lpVtbl->Release(p)
#define IDirectSoundFXChorus_SetAllParameters(p,a) (p)->lpVtbl->SetAllParameters(p,a)
#define IDirectSoundFXChorus_GetAllParameters(p,a) (p)->lpVtbl->GetAllParameters(p,a)
#else
#define IDirectSoundFXChorus_QueryInterface(p,a,b) (p)->QueryInterface(p,a,b)
#define IDirectSoundFXChorus_AddRef(p)             (p)->AddRef(p)
#define IDirectSoundFXChorus_Release(p)            (p)->Release(p)
#define IDirectSoundFXChorus_SetAllParameters(p,a) (p)->SetAllParameters(a)
#define IDirectSoundFXChorus_GetAllParameters(p,a) (p)->GetAllParameters(a)
#endif

typedef struct _DSFXFlanger
{
    FLOAT fWetDryMix;
    FLOAT fDepth;
    FLOAT fFeedback;
    FLOAT fFrequency;
    LONG  lWaveform;
    FLOAT fDelay;
    LONG  lPhase;
} DSFXFlanger, *LPDSFXFlanger;

typedef const DSFXFlanger *LPCDSFXFlanger;

#define DSFXFLANGER_DELAY_MIN       0.0f
#define DSFXFLANGER_DELAY_MAX       4.0f
#define DSFXFLANGER_DEPTH_MIN       0.0f
#define DSFXFLANGER_DEPTH_MAX     100.0f
#define DSFXFLANGER_FREQUENCY_MIN   0.0f
#define DSFXFLANGER_FREQUENCY_MAX  10.0f
#define DSFXFLANGER_FEEDBACK_MIN  -99.0f
#define DSFXFLANGER_FEEDBACK_MAX   99.0f
#define DSFXFLANGER_PHASE_MIN       0
#define DSFXFLANGER_PHASE_MAX       4
#define DSFXFLANGER_PHASE_NEG_180   0
#define DSFXFLANGER_PHASE_NEG_90    1
#define DSFXFLANGER_PHASE_ZERO      2
#define DSFXFLANGER_PHASE_90        3
#define DSFXFLANGER_PHASE_180       4
#define DSFXFLANGER_WAVE_SIN        1
#define DSFXFLANGER_WAVE_TRIANGLE   0
#define DSFXFLANGER_WETDRYMIX_MIN   0.0f
#define DSFXFLANGER_WETDRYMIX_MAX 100.0f

#define INTERFACE IDirectSoundFXFlanger
DECLARE_INTERFACE_(IDirectSoundFXFlanger,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID, void**) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;

    /*** IDirectSoundFXFlanger methods ***/
    STDMETHOD(SetAllParameters)(THIS_ const DSFXFlanger *flanger) PURE;
    STDMETHOD(GetAllParameters)(THIS_ DSFXFlanger *flanger) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IDirectSoundFXFlanger_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFXFlanger_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundFXFlanger_Release(p)            (p)->lpVtbl->Release(p)
#define IDirectSoundFXFlanger_SetAllParameters(p,a) (p)->lpVtbl->SetAllParameters(p,a)
#define IDirectSoundFXFlanger_GetAllParameters(p,a) (p)->lpVtbl->GetAllParameters(p,a)
#else
#define IDirectSoundFXFlanger_QueryInterface(p,a,b) (p)->QueryInterface(p,a,b)
#define IDirectSoundFXFlanger_AddRef(p)             (p)->AddRef(p)
#define IDirectSoundFXFlanger_Release(p)            (p)->Release(p)
#define IDirectSoundFXFlanger_SetAllParameters(p,a) (p)->SetAllParameters(a)
#define IDirectSoundFXFlanger_GetAllParameters(p,a) (p)->GetAllParameters(a)
#endif

typedef struct _DSFXEcho
{
    FLOAT fWetDryMix;
    FLOAT fFeedback;
    FLOAT fLeftDelay;
    FLOAT fRightDelay;
    LONG  lPanDelay;
} DSFXEcho, *LPDSFXEcho;

typedef const DSFXEcho *LPCDSFXEcho;

#define DSFXECHO_FEEDBACK_MIN      0.0f
#define DSFXECHO_FEEDBACK_MAX    100.0f
#define DSFXECHO_LEFTDELAY_MIN     1.0f
#define DSFXECHO_LEFTDELAY_MAX  2000.0f
#define DSFXECHO_PANDELAY_MIN      0
#define DSFXECHO_PANDELAY_MAX      1
#define DSFXECHO_RIGHTDELAY_MIN    1.0f
#define DSFXECHO_RIGHTDELAY_MAX 2000.0f
#define DSFXECHO_WETDRYMIX_MIN     0.0f
#define DSFXECHO_WETDRYMIX_MAX   100.0f

#define INTERFACE IDirectSoundFXEcho
DECLARE_INTERFACE_(IDirectSoundFXEcho,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID, void**) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;

    /*** IDirectSoundFXEcho methods ***/
    STDMETHOD(SetAllParameters)(THIS_ const DSFXEcho *echo) PURE;
    STDMETHOD(GetAllParameters)(THIS_ DSFXEcho *echo) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IDirectSoundFXEcho_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFXEcho_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundFXEcho_Release(p)            (p)->lpVtbl->Release(p)
#define IDirectSoundFXEcho_SetAllParameters(p,a) (p)->lpVtbl->SetAllParameters(p,a)
#define IDirectSoundFXEcho_GetAllParameters(p,a) (p)->lpVtbl->GetAllParameters(p,a)
#else
#define IDirectSoundFXEcho_QueryInterface(p,a,b) (p)->QueryInterface(p,a,b)
#define IDirectSoundFXEcho_AddRef(p)             (p)->AddRef(p)
#define IDirectSoundFXEcho_Release(p)            (p)->Release(p)
#define IDirectSoundFXEcho_SetAllParameters(p,a) (p)->SetAllParameters(a)
#define IDirectSoundFXEcho_GetAllParameters(p,a) (p)->GetAllParameters(a)
#endif

typedef struct _DSFXDistortion
{
    FLOAT fGain;
    FLOAT fEdge;
    FLOAT fPostEQCenterFrequency;
    FLOAT fPostEQBandwidth;
    FLOAT fPreLowpassCutoff;
} DSFXDistortion, *LPDSFXDistortion;

typedef const DSFXDistortion *LPCDSFXDistortion;

#define DSFXDISTORTION_EDGE_MIN                     0.0f
#define DSFXDISTORTION_EDGE_MAX                   100.0f
#define DSFXDISTORTION_GAIN_MIN                   -60.0f
#define DSFXDISTORTION_GAIN_MAX                     0.0f
#define DSFXDISTORTION_POSTEQCENTERFREQUENCY_MIN  100.0f
#define DSFXDISTORTION_POSTEQCENTERFREQUENCY_MAX 8000.0f
#define DSFXDISTORTION_POSTEQBANDWIDTH_MIN        100.0f
#define DSFXDISTORTION_POSTEQBANDWIDTH_MAX       8000.0f
#define DSFXDISTORTION_PRELOWPASSCUTOFF_MIN       100.0f
#define DSFXDISTORTION_PRELOWPASSCUTOFF_MAX      8000.0f

#define INTERFACE IDirectSoundFXDistortion
DECLARE_INTERFACE_(IDirectSoundFXDistortion,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID, void**) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;

    /*** IDirectSoundFXDistortion methods ***/
    STDMETHOD(SetAllParameters)(THIS_ const DSFXDistortion *distortion) PURE;
    STDMETHOD(GetAllParameters)(THIS_ DSFXDistortion *distortion) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IDirectSoundFXDistortion_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFXDistortion_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundFXDistortion_Release(p)            (p)->lpVtbl->Release(p)
#define IDirectSoundFXDistortion_SetAllParameters(p,a) (p)->lpVtbl->SetAllParameters(p,a)
#define IDirectSoundFXDistortion_GetAllParameters(p,a) (p)->lpVtbl->GetAllParameters(p,a)
#else
#define IDirectSoundFXDistortion_QueryInterface(p,a,b) (p)->QueryInterface(p,a,b)
#define IDirectSoundFXDistortion_AddRef(p)             (p)->AddRef(p)
#define IDirectSoundFXDistortion_Release(p)            (p)->Release(p)
#define IDirectSoundFXDistortion_SetAllParameters(p,a) (p)->SetAllParameters(a)
#define IDirectSoundFXDistortion_GetAllParameters(p,a) (p)->GetAllParameters(a)
#endif

typedef struct _DSFXCompressor
{
    FLOAT fGain;
    FLOAT fAttack;
    FLOAT fRelease;
    FLOAT fThreshold;
    FLOAT fRatio;
    FLOAT fPredelay;
} DSFXCompressor, *LPDSFXCompressor;

typedef const DSFXCompressor *LPCDSFXCompressor;

#define DSFXCOMPRESSOR_ATTACK_MIN       0.01f
#define DSFXCOMPRESSOR_ATTACK_MAX     500.0f
#define DSFXCOMPRESSOR_GAIN_MIN       -60.0f
#define DSFXCOMPRESSOR_GAIN_MAX        60.0f
#define DSFXCOMPRESSOR_PREDELAY_MIN     0.0f
#define DSFXCOMPRESSOR_PREDELAY_MAX     4.0f
#define DSFXCOMPRESSOR_RATIO_MIN        1.0f
#define DSFXCOMPRESSOR_RATIO_MAX      100.0f
#define DSFXCOMPRESSOR_RELEASE_MIN     50.0f
#define DSFXCOMPRESSOR_RELEASE_MAX   3000.0f
#define DSFXCOMPRESSOR_THRESHOLD_MIN  -60.0f
#define DSFXCOMPRESSOR_THRESHOLD_MAX    0.0f

#define INTERFACE IDirectSoundFXCompressor
DECLARE_INTERFACE_(IDirectSoundFXCompressor, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID, void**) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;

    /*** IDirectSoundFXCompressor methods ***/
    STDMETHOD(SetAllParameters)(THIS_ const DSFXCompressor *compressor) PURE;
    STDMETHOD(GetAllParameters)(THIS_ DSFXCompressor *compressor) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IDirectSoundFXCompressor_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFXCompressor_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundFXCompressor_Release(p)            (p)->lpVtbl->Release(p)
#define IDirectSoundFXCompressor_SetAllParameters(p,a) (p)->lpVtbl->SetAllParameters(p,a)
#define IDirectSoundFXCompressor_GetAllParameters(p,a) (p)->lpVtbl->GetAllParameters(p,a)
#else
#define IDirectSoundFXCompressor_QueryInterface(p,a,b) (p)->QueryInterface(p,a,b)
#define IDirectSoundFXCompressor_AddRef(p)             (p)->AddRef(p)
#define IDirectSoundFXCompressor_Release(p)            (p)->Release(p)
#define IDirectSoundFXCompressor_SetAllParameters(p,a) (p)->SetAllParameters(a)
#define IDirectSoundFXCompressor_GetAllParameters(p,a) (p)->GetAllParameters(a)
#endif

typedef struct _DSFXParamEq
{
    FLOAT fCenter;
    FLOAT fBandwidth;
    FLOAT fGain;
} DSFXParamEq, *LPDSFXParamEq;

typedef const DSFXParamEq *LPCDSFXParamEq;

#define DSFXPARAMEQ_BANDWIDTH_MIN     1.0f
#define DSFXPARAMEQ_BANDWIDTH_MAX    36.0f
#define DSFXPARAMEQ_CENTER_MIN       80.0f
#define DSFXPARAMEQ_CENTER_MAX    16000.0f
#define DSFXPARAMEQ_GAIN_MIN        -15.0f
#define DSFXPARAMEQ_GAIN_MAX         15.0f

#define INTERFACE IDirectSoundFXParamEq
DECLARE_INTERFACE_(IDirectSoundFXParamEq, IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID, void**) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;

    /*** IDirectSoundFXParamEq methods ***/
    STDMETHOD(SetAllParameters)(THIS_ const DSFXParamEq *param) PURE;
    STDMETHOD(GetAllParameters)(THIS_ DSFXParamEq *param) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IDirectSoundFXParamEq_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFXParamEq_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundFXParamEq_Release(p)            (p)->lpVtbl->Release(p)
#define IDirectSoundFXParamEq_SetAllParameters(p,a) (p)->lpVtbl->SetAllParameters(p,a)
#define IDirectSoundFXParamEq_GetAllParameters(p,a) (p)->lpVtbl->GetAllParameters(p,a)
#else
#define IDirectSoundFXParamEq_QueryInterface(p,a,b) (p)->QueryInterface(p,a,b)
#define IDirectSoundFXParamEq_AddRef(p)             (p)->AddRef(p)
#define IDirectSoundFXParamEq_Release(p)            (p)->Release(p)
#define IDirectSoundFXParamEq_SetAllParameters(p,a) (p)->SetAllParameters(a)
#define IDirectSoundFXParamEq_GetAllParameters(p,a) (p)->GetAllParameters(a)
#endif

typedef struct _DSFXWavesReverb
{
    FLOAT fInGain;
    FLOAT fReverbMix;
    FLOAT fReverbTime;
    FLOAT fHighFreqRTRatio;
} DSFXWavesReverb, *LPDSFXWavesReverb;

typedef const DSFXWavesReverb *LPCDSFXWavesReverb;

#define DSFX_WAVESREVERB_HIGHFREQRTRATIO_MIN       0.001f
#define DSFX_WAVESREVERB_HIGHFREQRTRATIO_MAX       0.999f
#define DSFX_WAVESREVERB_HIGHFREQRTRATIO_DEFAULT   0.001f
#define DSFX_WAVESREVERB_INGAIN_MIN              -96.0f
#define DSFX_WAVESREVERB_INGAIN_MAX                0.0f
#define DSFX_WAVESREVERB_INGAIN_DEFAULT            0.0f
#define DSFX_WAVESREVERB_REVERBMIX_MIN           -96.0f
#define DSFX_WAVESREVERB_REVERBMIX_MAX             0.0f
#define DSFX_WAVESREVERB_REVERBMIX_DEFAULT         0.0f
#define DSFX_WAVESREVERB_REVERBTIME_MIN            0.001f
#define DSFX_WAVESREVERB_REVERBTIME_MAX         3000.0f
#define DSFX_WAVESREVERB_REVERBTIME_DEFAULT     1000.0f

#define INTERFACE IDirectSoundFXWavesReverb
DECLARE_INTERFACE_(IDirectSoundFXWavesReverb,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD(QueryInterface)(THIS_ REFIID, void**) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;

    /*** IDirectSoundFXWavesReverb methods ***/
    STDMETHOD(SetAllParameters)(THIS_ const DSFXWavesReverb *reverb) PURE;
    STDMETHOD(GetAllParameters)(THIS_ DSFXWavesReverb *reverb) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
#define IDirectSoundFXWavesReverb_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectSoundFXWavesReverb_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectSoundFXWavesReverb_Release(p)            (p)->lpVtbl->Release(p)
#define IDirectSoundFXWavesReverb_SetAllParameters(p,a) (p)->lpVtbl->SetAllParameters(p,a)
#define IDirectSoundFXWavesReverb_GetAllParameters(p,a) (p)->lpVtbl->GetAllParameters(p,a)
#else
#define IDirectSoundFXWavesReverb_QueryInterface(p,a,b) (p)->QueryInterface(p,a,b)
#define IDirectSoundFXWavesReverb_AddRef(p)             (p)->AddRef(p)
#define IDirectSoundFXWavesReverb_Release(p)            (p)->Release(p)
#define IDirectSoundFXWavesReverb_SetAllParameters(p,a) (p)->SetAllParameters(a)
#define IDirectSoundFXWavesReverb_GetAllParameters(p,a) (p)->GetAllParameters(a)
#endif

enum
{
    DSFX_I3DL2_MATERIAL_PRESET_SINGLEWINDOW,
    DSFX_I3DL2_MATERIAL_PRESET_DOUBLEWINDOW,
    DSFX_I3DL2_MATERIAL_PRESET_THINDOOR,
    DSFX_I3DL2_MATERIAL_PRESET_THICKDOOR,
    DSFX_I3DL2_MATERIAL_PRESET_WOODWALL,
    DSFX_I3DL2_MATERIAL_PRESET_BRICKWALL,
    DSFX_I3DL2_MATERIAL_PRESET_STONEWALL,
    DSFX_I3DL2_MATERIAL_PRESET_CURTAIN
};

#define I3DL2_MATERIAL_PRESET_SINGLEWINDOW -2800,0.71f
#define I3DL2_MATERIAL_PRESET_DOUBLEWINDOW -5000,0.40f
#define I3DL2_MATERIAL_PRESET_THINDOOR     -1800,0.66f
#define I3DL2_MATERIAL_PRESET_THICKDOOR    -4400,0.64f
#define I3DL2_MATERIAL_PRESET_WOODWALL     -4000,0.50f
#define I3DL2_MATERIAL_PRESET_BRICKWALL    -5000,0.60f
#define I3DL2_MATERIAL_PRESET_STONEWALL    -6000,0.68f
#define I3DL2_MATERIAL_PRESET_CURTAIN      -1200,0.15f

enum
{
    DSFX_I3DL2_ENVIRONMENT_PRESET_DEFAULT,
    DSFX_I3DL2_ENVIRONMENT_PRESET_GENERIC,
    DSFX_I3DL2_ENVIRONMENT_PRESET_PADDEDCELL,
    DSFX_I3DL2_ENVIRONMENT_PRESET_ROOM,
    DSFX_I3DL2_ENVIRONMENT_PRESET_BATHROOM,
    DSFX_I3DL2_ENVIRONMENT_PRESET_LIVINGROOM,
    DSFX_I3DL2_ENVIRONMENT_PRESET_STONEROOM,
    DSFX_I3DL2_ENVIRONMENT_PRESET_AUDITORIUM,
    DSFX_I3DL2_ENVIRONMENT_PRESET_CONCERTHALL,
    DSFX_I3DL2_ENVIRONMENT_PRESET_CAVE,
    DSFX_I3DL2_ENVIRONMENT_PRESET_ARENA,
    DSFX_I3DL2_ENVIRONMENT_PRESET_HANGAR,
    DSFX_I3DL2_ENVIRONMENT_PRESET_CARPETEDHALLWAY,
    DSFX_I3DL2_ENVIRONMENT_PRESET_HALLWAY,
    DSFX_I3DL2_ENVIRONMENT_PRESET_STONECORRIDOR,
    DSFX_I3DL2_ENVIRONMENT_PRESET_ALLEY,
    DSFX_I3DL2_ENVIRONMENT_PRESET_FOREST,
    DSFX_I3DL2_ENVIRONMENT_PRESET_CITY,
    DSFX_I3DL2_ENVIRONMENT_PRESET_MOUNTAINS,
    DSFX_I3DL2_ENVIRONMENT_PRESET_QUARRY,
    DSFX_I3DL2_ENVIRONMENT_PRESET_PLAIN,
    DSFX_I3DL2_ENVIRONMENT_PRESET_PARKINGLOT,
    DSFX_I3DL2_ENVIRONMENT_PRESET_SEWERPIPE,
    DSFX_I3DL2_ENVIRONMENT_PRESET_UNDERWATER,
    DSFX_I3DL2_ENVIRONMENT_PRESET_SMALLROOM,
    DSFX_I3DL2_ENVIRONMENT_PRESET_MEDIUMROOM,
    DSFX_I3DL2_ENVIRONMENT_PRESET_LARGEROOM,
    DSFX_I3DL2_ENVIRONMENT_PRESET_MEDIUMHALL,
    DSFX_I3DL2_ENVIRONMENT_PRESET_LARGEHALL,
    DSFX_I3DL2_ENVIRONMENT_PRESET_PLATE
};

#define I3DL2_ENVIRONMENT_PRESET_DEFAULT         -1000,-100,0.0f,1.49f,0.83f,-2602,0.007f,200,0.011f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_GENERIC         -1000,-100,0.0f,1.49f,0.83f,-2602,0.007f,200,0.011f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_PADDEDCELL      -1000,-6000,0.0f,0.17f,0.10f,-1204,0.001f,207,0.002f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_ROOM            -1000,-454,0.0f,0.40f,0.83f,-1646,0.002f,53,0.003f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_BATHROOM        -1000,-1200,0.0f,1.49f,0.54f,-370,0.007f,1030,0.011f,100.0f,60.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_LIVINGROOM      -1000,-6000,0.0f,0.50f,0.10f,-1376,0.003f,-1104,0.004f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_STONEROOM       -1000,-300,0.0f,2.31f,0.64f,-711,0.012f,83,0.017f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_AUDITORIUM      -1000,-476,0.0f,4.32f,0.59f,-789,0.020f,-289,0.030f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_CONCERTHALL     -1000,-500,0.0f,3.92f,0.70f,-1230,0.020f,-2,0.029f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_CAVE            -1000,0,0.0f,2.91f,1.30f,-602,0.015f,-302,0.022f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_ARENA           -1000,-698,0.0f,7.24f,0.33f,-1166,0.020f,16,0.030f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_HANGAR          -1000,-1000,0.0f,10.05f,0.23f,-602,0.020f,198,0.030f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_CARPETEDHALLWAY -1000,-4000,0.0f,0.30f,0.10f,-1831,0.002f,-1630,0.030f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_HALLWAY         -1000,-300,0.0f,1.49f,0.59f,-1219,0.007f,441,0.011f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_STONECORRIDOR   -1000,-237,0.0f,2.70f,0.79f,-1214,0.013f,395,0.020f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_ALLEY           -1000,-270,0.0f,1.49f,0.86f,-1204,0.007f,-4,0.011f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_FOREST          -1000,-3300,0.0f,1.49f,0.54f,-2560,0.162f,-613,0.088f,79.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_CITY            -1000,-800,0.0f,1.49f,0.67f,-2273,0.007f,2217,0.011f,50.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_MOUNTAINS       -1000,-2500,0.0f,1.49f,0.21f,-2780,0.300f,-2014,0.100f,27.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_QUARRY          -1000,-1000,0.0f,1.49f,0.83f,-10000,0.061f,500,0.025f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_PLAIN           -1000,-2000,0.0f,1.49f,0.50f,-2466,0.179f,-2514,0.100f,21.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_PARKINGLOT      -1000,0,0.0f,1.65f,1.50f,-1363,0.008f,-1153,0.012f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_SEWERPIPE       -1000,-1000,0.0f,2.81f,0.14f,429,0.014f,648,0.011f,80.0f,60.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_UNDERWATER      -1000,-4000,0.0f,1.49f,0.10f,-449,0.007f,1700,0.011f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_SMALLROOM       -1000,-600,0.0f,1.10f,0.83f,-400,0.005f,500,0.010f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_MEDIUMROOM      -1000,-600,0.0f,1.30f,0.83f,-1000,0.010f,-200,0.020f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_LARGEROOM       -1000,-600,0.0f,1.50f,0.83f,-1600,0.020f,-1000,0.040f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_MEDIUMHALL      -1000,-600,0.0f,1.80f,0.70f,-1300,0.015f,-800,0.030f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_LARGEHALL       -1000,-600,0.0f,1.80f,0.70f,-2000,0.030f,-1400,0.060f,100.0f,100.0f,5000.0f
#define I3DL2_ENVIRONMENT_PRESET_PLATE           -1000,-200,0.0f,1.30f,0.90f,0,0.002f,0,0.010f,100.0f,75.0f,5000.0f

#ifdef __cplusplus
} /* extern "C" */
#endif /* defined(__cplusplus) */

#endif /* __DSOUND_INCLUDED__ */
