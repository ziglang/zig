#undef INTERFACE
/*
 *  DirectMusic Software Synth Definitions
 *
 *  Copyright (C) 2003-2004 Rok Mandeljc
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __WINE_DMUSIC_SOFTWARESYNTH_H
#define __WINE_DMUSIC_SOFTWARESYNTH_H

#include <dmusicc.h>

/*****************************************************************************
 * Registry path
 */
#define REGSTR_PATH_SOFTWARESYNTHS "Software\\Microsoft\\DirectMusic\\SoftwareSynths"


/*****************************************************************************
 * Predeclare the interfaces
 */
/* IIDs */
DEFINE_GUID(IID_IDirectMusicSynth,     0x09823661,0x5c85,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(IID_IDirectMusicSynth8,    0x53cab625,0x2711,0x4c9f,0x9d,0xe7,0x1b,0x7f,0x92,0x5f,0x6f,0xc8);
DEFINE_GUID(IID_IDirectMusicSynthSink, 0x09823663,0x5c85,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);

/* typedef definitions */
typedef struct IDirectMusicSynth *LPDIRECTMUSICSYNTH;
typedef struct IDirectMusicSynth8 *LPDIRECTMUSICSYNTH8;
typedef struct IDirectMusicSynthSink *LPDIRECTMUSICSYNTHSINK;

/* GUIDs - property set */
DEFINE_GUID(GUID_DMUS_PROP_SetSynthSink,   0x0a3a5ba5,0x37b6,0x11d2,0xb9,0xf9,0x00,0x00,0xf8,0x75,0xac,0x12);
DEFINE_GUID(GUID_DMUS_PROP_SinkUsesDSound, 0xbe208857,0x8952,0x11d2,0xba,0x1c,0x00,0x00,0xf8,0x75,0xac,0x12);


/*****************************************************************************
 * Flags
 */
#define REFRESH_F_LASTBUFFER        0x1


/*****************************************************************************
 * Structures
 */
#ifndef _DMUS_VOICE_STATE_DEFINED
#define _DMUS_VOICE_STATE_DEFINED

/* typedef definition */
typedef struct _DMUS_VOICE_STATE DMUS_VOICE_STATE, *LPDMUS_VOICE_STATE;

/* actual structure */
struct _DMUS_VOICE_STATE {
	WINBOOL         bExists;
	SAMPLE_POSITION spPosition;
}; 
#endif /* _DMUS_VOICE_STATE_DEFINED */


/*****************************************************************************
 * IDirectMusicSynth interface
 */
#define INTERFACE IDirectMusicSynth
DECLARE_INTERFACE_(IDirectMusicSynth,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicSynth methods ***/
    STDMETHOD(Open)(THIS_ LPDMUS_PORTPARAMS pPortParams) PURE;
    STDMETHOD(Close)(THIS) PURE;
    STDMETHOD(SetNumChannelGroups)(THIS_ DWORD dwGroups) PURE;
    STDMETHOD(Download)(THIS_ LPHANDLE phDownload, LPVOID pvData, LPBOOL pbFree) PURE;
    STDMETHOD(Unload)(THIS_ HANDLE hDownload, HRESULT (CALLBACK* lpFreeHandle)(HANDLE,HANDLE), HANDLE hUserData) PURE;
    STDMETHOD(PlayBuffer)(THIS_ REFERENCE_TIME rt, LPBYTE pbBuffer, DWORD cbBuffer) PURE;
    STDMETHOD(GetRunningStats)(THIS_ LPDMUS_SYNTHSTATS pStats) PURE;
    STDMETHOD(GetPortCaps)(THIS_ LPDMUS_PORTCAPS pCaps) PURE;
    STDMETHOD(SetMasterClock)(THIS_ IReferenceClock *pClock) PURE;
    STDMETHOD(GetLatencyClock)(THIS_ IReferenceClock **ppClock) PURE;
    STDMETHOD(Activate)(THIS_ WINBOOL fEnable) PURE;
    STDMETHOD(SetSynthSink)(THIS_ struct IDirectMusicSynthSink *pSynthSink) PURE;
    STDMETHOD(Render)(THIS_ short *pBuffer, DWORD dwLength, LONGLONG llPosition) PURE;
    STDMETHOD(SetChannelPriority)(THIS_ DWORD dwChannelGroup, DWORD dwChannel, DWORD dwPriority) PURE;
    STDMETHOD(GetChannelPriority)(THIS_ DWORD dwChannelGroup, DWORD dwChannel, LPDWORD pdwPriority) PURE;
    STDMETHOD(GetFormat)(THIS_ LPWAVEFORMATEX pWaveFormatEx, LPDWORD pdwWaveFormatExSiz) PURE;
    STDMETHOD(GetAppend)(THIS_ DWORD *pdwAppend) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicSynth_QueryInterface(p,a,b)       (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicSynth_AddRef(p)                   (p)->lpVtbl->AddRef(p)
#define IDirectMusicSynth_Release(p)                  (p)->lpVtbl->Release(p)
/*** IDirectMusicSynth methods ***/
#define IDirectMusicSynth_Open(p,a)                   (p)->lpVtbl->Open(p,a)
#define IDirectMusicSynth_Close(p)                    (p)->lpVtbl->Close(p)
#define IDirectMusicSynth_SetNumChannelGroups(p,a)    (p)->lpVtbl->SetNumChannelGroups(p,a)
#define IDirectMusicSynth_Download(p,a,b,c)           (p)->lpVtbl->Download(p,a,b,c)
#define IDirectMusicSynth_Unload(p,a,b,c)             (p)->lpVtbl->Unload(p,a,b,c)
#define IDirectMusicSynth_PlayBuffer(p,a,b,c)         (p)->lpVtbl->PlayBuffer(p,a,b,c)
#define IDirectMusicSynth_GetRunningStats(p,a)        (p)->lpVtbl->GetRunningStats(p,a)
#define IDirectMusicSynth_GetPortCaps(p,a)            (p)->lpVtbl->GetPortCaps(p,a)
#define IDirectMusicSynth_SetMasterClock(p,a)         (p)->lpVtbl->SetMasterClock(p,a)
#define IDirectMusicSynth_GetLatencyClock(p,a)        (p)->lpVtbl->GetLatencyClock(p,a)
#define IDirectMusicSynth_Activate(p,a)               (p)->lpVtbl->Activate(p,a)
#define IDirectMusicSynth_SetSynthSink(p,a)           (p)->lpVtbl->SetSynthSink(p,a)
#define IDirectMusicSynth_Render(p,a,b,c)             (p)->lpVtbl->Render(p,a,b,c)
#define IDirectMusicSynth_SetChannelPriority(p,a,b,c) (p)->lpVtbl->SetChannelPriority(p,a,b,c)
#define IDirectMusicSynth_GetChannelPriority(p,a,b,c) (p)->lpVtbl->GetChannelPriority(p,a,b,c)
#define IDirectMusicSynth_GetFormat(p,a,b)            (p)->lpVtbl->GetFormat(p,a,b)
#define IDirectMusicSynth_GetAppend(p,a)              (p)->lpVtbl->GetAppend(p,a)
#endif


/*****************************************************************************
 * IDirectMusicSynth8 interface
 */
#define INTERFACE IDirectMusicSynth8
DECLARE_INTERFACE_(IDirectMusicSynth8,IDirectMusicSynth)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicSynth methods ***/
    STDMETHOD(Open)(THIS_ LPDMUS_PORTPARAMS pPortParams) PURE;
    STDMETHOD(Close)(THIS) PURE;
    STDMETHOD(SetNumChannelGroups)(THIS_ DWORD dwGroups) PURE;
    STDMETHOD(Download)(THIS_ LPHANDLE phDownload, LPVOID pvData, LPBOOL pbFree) PURE;
    STDMETHOD(Unload)(THIS_ HANDLE hDownload, HRESULT (CALLBACK* lpFreeHandle)(HANDLE,HANDLE), HANDLE hUserData) PURE;
    STDMETHOD(PlayBuffer)(THIS_ REFERENCE_TIME rt, LPBYTE pbBuffer, DWORD cbBuffer) PURE;
    STDMETHOD(GetRunningStats)(THIS_ LPDMUS_SYNTHSTATS pStats) PURE;
    STDMETHOD(GetPortCaps)(THIS_ LPDMUS_PORTCAPS pCaps) PURE;
    STDMETHOD(SetMasterClock)(THIS_ IReferenceClock *pClock) PURE;
    STDMETHOD(GetLatencyClock)(THIS_ IReferenceClock **ppClock) PURE;
    STDMETHOD(Activate)(THIS_ WINBOOL fEnable) PURE;
    STDMETHOD(SetSynthSink)(THIS_ struct IDirectMusicSynthSink *pSynthSink) PURE;
    STDMETHOD(Render)(THIS_ short *pBuffer, DWORD dwLength, LONGLONG llPosition) PURE;
    STDMETHOD(SetChannelPriority)(THIS_ DWORD dwChannelGroup, DWORD dwChannel, DWORD dwPriority) PURE;
    STDMETHOD(GetChannelPriority)(THIS_ DWORD dwChannelGroup, DWORD dwChannel, LPDWORD pdwPriority) PURE;
    STDMETHOD(GetFormat)(THIS_ LPWAVEFORMATEX pWaveFormatEx, LPDWORD pdwWaveFormatExSiz) PURE;
    STDMETHOD(GetAppend)(THIS_ DWORD *pdwAppend) PURE;
    /*** IDirectMusicSynth8 methods ***/
    STDMETHOD(PlayVoice)(THIS_ REFERENCE_TIME rt, DWORD dwVoiceId, DWORD dwChannelGroup, DWORD dwChannel, DWORD dwDLId, LONG prPitch, LONG vrVolume, SAMPLE_TIME stVoiceStart, SAMPLE_TIME stLoopStart, SAMPLE_TIME stLoopEnd) PURE;
    STDMETHOD(StopVoice)(THIS_ REFERENCE_TIME rt, DWORD dwVoiceId) PURE;
    STDMETHOD(GetVoiceState)(THIS_ DWORD dwVoice[], DWORD cbVoice, DMUS_VOICE_STATE dwVoiceState[]) PURE;
    STDMETHOD(Refresh)(THIS_ DWORD dwDownloadID, DWORD dwFlags) PURE;
    STDMETHOD(AssignChannelToBuses)(THIS_ DWORD dwChannelGroup, DWORD dwChannel, LPDWORD pdwBuses, DWORD cBuses) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicSynth8_QueryInterface(p,a,b)            (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicSynth8_AddRef(p)                        (p)->lpVtbl->AddRef(p)
#define IDirectMusicSynth8_Release(p)                       (p)->lpVtbl->Release(p)
/*** IDirectMusicSynth methods ***/
#define IDirectMusicSynth8_Open(p,a)                        (p)->lpVtbl->Open(p,a)
#define IDirectMusicSynth8_Close(p)                         (p)->lpVtbl->Close(p)
#define IDirectMusicSynth8_SetNumChannelGroups(p,a)         (p)->lpVtbl->SetNumChannelGroups(p,a)
#define IDirectMusicSynth8_Download(p,a,b,c)                (p)->lpVtbl->Download(p,a,b,c)
#define IDirectMusicSynth8_Unload(p,a,b,c)                  (p)->lpVtbl->Unload(p,a,b,c)
#define IDirectMusicSynth8_PlayBuffer(p,a,b,c)              (p)->lpVtbl->PlayBuffer(p,a,b,c)
#define IDirectMusicSynth8_GetRunningStats(p,a)             (p)->lpVtbl->GetRunningStats(p,a)
#define IDirectMusicSynth8_GetPortCaps(p,a)                 (p)->lpVtbl->GetPortCaps(p,a)
#define IDirectMusicSynth8_SetMasterClock(p,a)              (p)->lpVtbl->SetMasterClock(p,a)
#define IDirectMusicSynth8_GetLatencyClock(p,a)             (p)->lpVtbl->GetLatencyClock(p,a)
#define IDirectMusicSynth8_Activate(p,a)                    (p)->lpVtbl->Activate(p,a)
#define IDirectMusicSynth8_SetSynthSink(p,a)                (p)->lpVtbl->SetSynthSink(p,a)
#define IDirectMusicSynth8_Render(p,a,b,c)                  (p)->lpVtbl->Render(p,a,b,c)
#define IDirectMusicSynth8_SetChannelPriority(p,a,b,c)      (p)->lpVtbl->SetChannelPriority(p,a,b,c)
#define IDirectMusicSynth8_GetChannelPriority(p,a,b,c)      (p)->lpVtbl->GetChannelPriority(p,a,b,c)
#define IDirectMusicSynth8_GetFormat(p,a,b)                 (p)->lpVtbl->GetFormat(p,a,b)
#define IDirectMusicSynth8_GetAppend(p,a)                   (p)->lpVtbl->GetAppend(p,a)
/*** IDirectMusicSynth8 methods ***/
#define IDirectMusicSynth8_PlayVoice(p,a,b,c,d,e,f,g,h,i,j) (p)->lpVtbl->PlayVoice(p,a,b,c,d,e,f,g,h,i,j)
#define IDirectMusicSynth8_StopVoice(p,a,b)                 (p)->lpVtbl->StopVoice(p,a,b)
#define IDirectMusicSynth8_GetVoiceState(p,a,b,c)           (p)->lpVtbl->GetVoiceState(p,a,b,c)
#define IDirectMusicSynth8_Refresh(p,a,b)                   (p)->lpVtbl->Refresh(p,a,b)
#define IDirectMusicSynth8_AssignChannelToBuses(p,a,b,c,d)  (p)->lpVtbl->AssignChannelToBuses(p,a,b,c,d)
#endif


/*****************************************************************************
 * IDirectMusicSynthSink interface
 */
#define INTERFACE IDirectMusicSynthSink
DECLARE_INTERFACE_(IDirectMusicSynthSink,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicSynthSink methods ***/
    STDMETHOD(Init)(THIS_ IDirectMusicSynth *pSynth) PURE;
    STDMETHOD(SetMasterClock)(THIS_ IReferenceClock *pClock) PURE;
    STDMETHOD(GetLatencyClock)(THIS_ IReferenceClock **ppClock) PURE;
    STDMETHOD(Activate)(THIS_ WINBOOL fEnable) PURE;
    STDMETHOD(SampleToRefTime)(THIS_ LONGLONG llSampleTime, REFERENCE_TIME *prfTime) PURE;
    STDMETHOD(RefTimeToSample)(THIS_ REFERENCE_TIME rfTime, LONGLONG *pllSampleTime) PURE;
    STDMETHOD(SetDirectSound)(THIS_ LPDIRECTSOUND pDirectSound, LPDIRECTSOUNDBUFFER pDirectSoundBuffer) PURE;
    STDMETHOD(GetDesiredBufferSize)(THIS_ LPDWORD pdwBufferSizeInSamples) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicSynthSink_QueryInterface(p,a,b)      (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicSynthSink_AddRef(p)                  (p)->lpVtbl->AddRef(p)
#define IDirectMusicSynthSink_Release(p)                 (p)->lpVtbl->Release(p)
/*** IDirectMusicSynth methods ***/
#define IDirectMusicSynthSink_Init(p,a)                  (p)->lpVtbl->Init(p,a)
#define IDirectMusicSynthSink_SetMasterClock(p,a)        (p)->lpVtbl->SetMasterClock(p,a)
#define IDirectMusicSynthSink_GetLatencyClock(p,a)       (p)->lpVtbl->GetLatencyClock(p,a)
#define IDirectMusicSynthSink_Activate(p,a)              (p)->lpVtbl->Activate(p,a)
#define IDirectMusicSynthSink_SampleToRefTime(p,a,b)     (p)->lpVtbl->SampleToRefTime(p,a,b)
#define IDirectMusicSynthSink_RefTimeToSample(p,a,b)     (p)->lpVtbl->RefTimeToSample(p,a,b)
#define IDirectMusicSynthSink_SetDirectSound(p,a,b)      (p)->lpVtbl->SetDirectSound(p,a,b)
#define IDirectMusicSynthSink_GetDesiredBufferSize(p,a)  (p)->lpVtbl->GetDesiredBufferSize(p,a)
#endif

#endif /* __WINE_DMUSIC_SOFTWARESYNTH_H */
