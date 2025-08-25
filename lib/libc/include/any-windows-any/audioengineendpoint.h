/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __INC_AUDIOENGINEENDPOINT__
#define __INC_AUDIOENGINEENDPOINT__

#include <endpointvolume.h>
#include <audioapotypes.h>

#if (_WIN32_WINNT >= 0x0601)
#ifdef __cplusplus
extern "C" {
#endif

typedef LONGLONG HNSTIME;

typedef enum AE_POSITION_FLAGS {
  POSITION_INVALID         = 0,
  POSITION_DISCONTINUOUS   = 1,
  POSITION_CONTINUOUS      = 2,
  POSITION_QPC_ERROR       = 4 
} AE_POSITION_FLAGS;

typedef struct AE_CURRENT_POSITION {
  UINT64            u64DevicePosition;
  UINT64            u64StreamPosition;
  UINT64            u64PaddingFrames;
  HNSTIME           hnsQPCPosition;
  FLOAT32           f32FramesPerSecond;
  AE_POSITION_FLAGS Flag;
} AE_CURRENT_POSITION, *PAE_CURRENT_POSITION;

typedef struct _AUDIO_ENDPOINT_EXCLUSIVE_CREATE_PARAMS {
  UINT32       u32Size;
  LONGLONG     hConnection;
  WINBOOL      bIsRtCapable;
  HNSTIME      hnsBufferDuration;
  HNSTIME      hnsPeriod;
  UINT32       u32LatencyCoefficient;
  WAVEFORMATEX wfxDeviceFormat;
} AUDIO_ENDPOINT_EXCLUSIVE_CREATE_PARAMS, *PAUDIO_ENDPOINT_EXCLUSIVE_CREATE_PARAMS;

typedef struct _AUDIO_ENDPOINT_SHARED_CREATE_PARAMS {
  UINT32 u32Size;
  UINT32 u32TSSessionId;
} AUDIO_ENDPOINT_SHARED_CREATE_PARAMS, *PAUDIO_ENDPOINT_SHARED_CREATE_PARAMS;

#ifdef __cplusplus
}
#endif

#ifndef __IAudioDeviceEndpoint_FWD_DEFINED__
#define __IAudioDeviceEndpoint_FWD_DEFINED__
typedef struct IAudioDeviceEndpoint IAudioDeviceEndpoint;
#endif

#ifndef __IAudioEndpoint_FWD_DEFINED__
#define __IAudioEndpoint_FWD_DEFINED__
typedef struct IAudioEndpoint IAudioEndpoint;
#endif

#ifndef __IAudioEndpointControl_FWD_DEFINED__
#define __IAudioEndpointControl_FWD_DEFINED__
typedef struct IAudioEndpointControl IAudioEndpointControl;
#endif

#ifndef __IAudioEndpointRT_FWD_DEFINED__
#define __IAudioEndpointRT_FWD_DEFINED__
typedef struct IAudioEndpointRT IAudioEndpointRT;
#endif

#ifndef __IAudioEndpointVolumeEx_FWD_DEFINED__
#define __IAudioEndpointVolumeEx_FWD_DEFINED__
typedef struct IAudioEndpointVolumeEx IAudioEndpointVolumeEx;
#endif

#ifndef __IAudioInputEndpointRT_FWD_DEFINED__
#define __IAudioInputEndpointRT_FWD_DEFINED__
typedef struct IAudioInputEndpointRT IAudioInputEndpointRT;
#endif

#ifndef __IAudioInputEndpointRT_FWD_DEFINED__
#define __IAudioInputEndpointRT_FWD_DEFINED__
typedef struct IAudioOutputEndpointRT IAudioOutputEndpointRT;
#endif

#undef  INTERFACE
#define INTERFACE IAudioDeviceEndpoint
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IAudioDeviceEndpoint,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IAudioDeviceEndpoint methods */
    STDMETHOD_(HRESULT,GetEventDrivenCapable)(THIS_ WINBOOL *pbIsEventCapable) PURE;
    STDMETHOD_(HRESULT,GetRTCaps)(THIS_ WINBOOL *pbIsRTCapable) PURE;
    STDMETHOD_(HRESULT,SetBuffer)(THIS_ HNSTIME MaxPeriod,UINT32 u32LatencyCoefficient) PURE;
    STDMETHOD_(HRESULT,WriteExclusiveModeParametersToSharedMemory)(THIS_ UINT_PTR hTargetProcess,HNSTIME hnsPeriod,HNSTIME hnsBufferDuration,UINT32 u32LatencyCoefficient,UINT32 *pu32SharedMemorySize,UINT_PTR *phSharedMemory) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IAudioDeviceEndpoint_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAudioDeviceEndpoint_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAudioDeviceEndpoint_Release(This) (This)->lpVtbl->Release(This)
#define IAudioDeviceEndpoint_GetEventDrivenCapable(This,pbIsEventCapable) (This)->lpVtbl->GetEventDrivenCapable(This,pbIsEventCapable)
#define IAudioDeviceEndpoint_GetRTCaps(This,pbIsRTCapable) (This)->lpVtbl->GetRTCaps(This,pbIsRTCapable)
#define IAudioDeviceEndpoint_SetBuffer(This,MaxPeriod,u32LatencyCoefficient) (This)->lpVtbl->SetBuffer(This,MaxPeriod,u32LatencyCoefficient)
#define IAudioDeviceEndpoint_WriteExclusiveModeParametersToSharedMemory(This,hTargetProcess,hnsPeriod,hnsBufferDuration,u32LatencyCoefficient,pu32SharedMemorySize,phSharedMemory) (This)->lpVtbl->WriteExclusiveModeParametersToSharedMemory(This,hTargetProcess,hnsPeriod,hnsBufferDuration,u32LatencyCoefficient,pu32SharedMemorySize,phSharedMemory)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IAudioEndpoint
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IAudioEndpoint,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IAudioEndpoint methods */
    STDMETHOD_(HRESULT,GetFrameFormat)(THIS_ WAVEFORMATEX **ppFormat) PURE;
    STDMETHOD_(HRESULT,GetFramesPerPacket)(THIS_ UINT32 *pFramesPerPacket) PURE;
    STDMETHOD_(HRESULT,GetLatency)(THIS_ HNSTIME *pLatency) PURE;
    STDMETHOD_(HRESULT,SetEventHandle)(THIS_ HANDLE eventHandle) PURE;
    STDMETHOD_(HRESULT,SetStreamFlags)(THIS_ DWORD streamFlags) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IAudioEndpoint_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAudioEndpoint_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAudioEndpoint_Release(This) (This)->lpVtbl->Release(This)
#define IAudioEndpoint_GetFrameFormat(This,ppFormat) (This)->lpVtbl->GetFrameFormat(This,ppFormat)
#define IAudioEndpoint_GetFramesPerPacket(This,pFramesPerPacket) (This)->lpVtbl->GetFramesPerPacket(This,pFramesPerPacket)
#define IAudioEndpoint_GetLatency(This,pLatency) (This)->lpVtbl->GetLatency(This,pLatency)
#define IAudioEndpoint_SetEventHandle(This,eventHandle) (This)->lpVtbl->SetEventHandle(This,eventHandle)
#define IAudioEndpoint_SetStreamFlags(This,streamFlags) (This)->lpVtbl->SetStreamFlags(This,streamFlags)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IAudioEndpointControl
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IAudioEndpointControl,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IAudioEndpointControl methods */
    STDMETHOD_(HRESULT,Reset)(THIS) PURE;
    STDMETHOD_(HRESULT,Start)(THIS) PURE;
    STDMETHOD_(HRESULT,Stop)(THIS) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IAudioEndpointControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAudioEndpointControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAudioEndpointControl_Release(This) (This)->lpVtbl->Release(This)
#define IAudioEndpointControl_Reset() (This)->lpVtbl->Reset(This)
#define IAudioEndpointControl_Start() (This)->lpVtbl->Start(This)
#define IAudioEndpointControl_Stop() (This)->lpVtbl->Stop(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IAudioEndpointRT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IAudioEndpointRT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IAudioEndpointRT methods */
    STDMETHOD(GetCurrentPadding)(THIS_ HNSTIME *pPadding,AE_CURRENT_POSITION *pAeCurrentPosition) PURE;
    STDMETHOD(ProcessingComplete)(THIS) PURE;
    STDMETHOD_(HRESULT,SetPinActive)(THIS) PURE;
    STDMETHOD_(HRESULT,SetPinInactive)(THIS) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IAudioEndpointRT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAudioEndpointRT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAudioEndpointRT_Release(This) (This)->lpVtbl->Release(This)
#define IAudioEndpointRT_GetCurrentPadding(This,pPadding,pAeCurrentPosition) (This)->lpVtbl->GetCurrentPadding(This,pPadding,pAeCurrentPosition)
#define IAudioEndpointRT_ProcessingComplete() (This)->lpVtbl->ProcessingComplete(This)
#define IAudioEndpointRT_SetPinActive() (This)->lpVtbl->SetPinActive(This)
#define IAudioEndpointRT_SetPinInactive() (This)->lpVtbl->SetPinInactive(This)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IAudioEndpointVolumeEx
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IAudioEndpointVolumeEx,IAudioEndpointVolume)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IAudioEndpointVolume methods */
    STDMETHOD_(HRESULT,GetChannelCount)(THIS_ UINT *pnChannelCount) PURE;
    STDMETHOD_(HRESULT,GetChannelVolumeLevel)(THIS_ UINT nChannel,float *pfLevelDB) PURE;
    STDMETHOD_(HRESULT,GetChannelVolumeLevelScalar)(THIS_ UINT nChannel,float *pfLevel) PURE;
    STDMETHOD_(HRESULT,GetMasterVolumeLevel)(THIS_ float *pfLevelDB) PURE;
    STDMETHOD_(HRESULT,GetMasterVolumeLevelScalar)(THIS_ float *pfLevel) PURE;
    STDMETHOD_(HRESULT,GetMute)(THIS_ WINBOOL *pbMute) PURE;
    STDMETHOD_(HRESULT,GetVolumeRange)(THIS_ float *pfLevelMinDB,float *pfLevelMaxDB,float *pfVolumeIncrementDB) PURE;
    STDMETHOD_(HRESULT,GetVolumeStepInfo)(THIS_ UINT *pnStep,UINT *pnStepCount) PURE;
    STDMETHOD_(HRESULT,QueryHardwareSupport)(THIS_ DWORD *pdwHardwareSupportMask) PURE;
    STDMETHOD_(HRESULT,RegisterControlChangeNotify)(THIS_ IAudioEndpointVolumeCallback *pNotify) PURE;
    STDMETHOD_(HRESULT,SetChannelVolumeLevel)(THIS_ UINT nChannel,float fLevelDB,LPCGUID pguidEventContext) PURE;
    STDMETHOD_(HRESULT,SetChannelVolumeLevelScalar)(THIS_ UINT nChannel,float fLevel,LPCGUID pguidEventContext) PURE;
    STDMETHOD_(HRESULT,SetMasterVolumeLevel)(THIS_ float fLevelDB,LPCGUID pguidEventContext) PURE;
    STDMETHOD_(HRESULT,SetMasterVolumeLevelScalar)(THIS_ float fLevel,LPCGUID pguidEventContext) PURE;
    STDMETHOD_(HRESULT,SetMute)(THIS_ WINBOOL bMute,LPCGUID pguidEventContext) PURE;
    STDMETHOD_(HRESULT,UnregisterControlChangeNotify)(THIS_ IAudioEndpointVolumeCallback *pNotify) PURE;
    STDMETHOD_(HRESULT,VolumeStepDown)(THIS_ LPCGUID pguidEventContext) PURE;
    STDMETHOD_(HRESULT,VolumeStepUp)(THIS_ LPCGUID pguidEventContext) PURE;

    /* IAudioEndpointVolumeEx methods */
    STDMETHOD_(HRESULT,GetVolumeRangeChannel)(THIS_ UINT iChannel,float *pflVolumeMinDB,float *pflVolumeMaxDB,float *pflVolumeIncrementDB) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IAudioEndpointVolumeEx_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAudioEndpointVolumeEx_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAudioEndpointVolumeEx_Release(This) (This)->lpVtbl->Release(This)
#define IAudioEndpointVolumeEx_GetChannelCount(This,pnChannelCount) (This)->lpVtbl->GetChannelCount(This,pnChannelCount)
#define IAudioEndpointVolumeEx_GetChannelVolumeLevel(This,nChannel,pfLevelDB) (This)->lpVtbl->GetChannelVolumeLevel(This,nChannel,pfLevelDB)
#define IAudioEndpointVolumeEx_GetChannelVolumeLevelScalar(This,nChannel,pfLevel) (This)->lpVtbl->GetChannelVolumeLevelScalar(This,nChannel,pfLevel)
#define IAudioEndpointVolumeEx_GetMasterVolumeLevel(This,pfLevelDB) (This)->lpVtbl->GetMasterVolumeLevel(This,pfLevelDB)
#define IAudioEndpointVolumeEx_GetMasterVolumeLevelScalar(This,pfLevel) (This)->lpVtbl->GetMasterVolumeLevelScalar(This,pfLevel)
#define IAudioEndpointVolumeEx_GetMute(This,pbMute) (This)->lpVtbl->GetMute(This,pbMute)
#define IAudioEndpointVolumeEx_GetVolumeRange(This,pfLevelMinDB,pfLevelMaxDB,pfVolumeIncrementDB) (This)->lpVtbl->GetVolumeRange(This,pfLevelMinDB,pfLevelMaxDB,pfVolumeIncrementDB)
#define IAudioEndpointVolumeEx_GetVolumeStepInfo(This,pnStep,pnStepCount) (This)->lpVtbl->GetVolumeStepInfo(This,pnStep,pnStepCount)
#define IAudioEndpointVolumeEx_QueryHardwareSupport(This,pdwHardwareSupportMask) (This)->lpVtbl->QueryHardwareSupport(This,pdwHardwareSupportMask)
#define IAudioEndpointVolumeEx_RegisterControlChangeNotify(This,pNotify) (This)->lpVtbl->RegisterControlChangeNotify(This,pNotify)
#define IAudioEndpointVolumeEx_SetChannelVolumeLevel(This,nChannel,fLevelDB,pguidEventContext) (This)->lpVtbl->SetChannelVolumeLevel(This,nChannel,fLevelDB,pguidEventContext)
#define IAudioEndpointVolumeEx_SetChannelVolumeLevelScalar(This,nChannel,fLevel,pguidEventContext) (This)->lpVtbl->SetChannelVolumeLevelScalar(This,nChannel,fLevel,pguidEventContext)
#define IAudioEndpointVolumeEx_SetMasterVolumeLevel(This,fLevelDB,pguidEventContext) (This)->lpVtbl->SetMasterVolumeLevel(This,fLevelDB,pguidEventContext)
#define IAudioEndpointVolumeEx_SetMasterVolumeLevelScalar(This,fLevel,pguidEventContext) (This)->lpVtbl->SetMasterVolumeLevelScalar(This,fLevel,pguidEventContext)
#define IAudioEndpointVolumeEx_SetMute(This,bMute,pguidEventContext) (This)->lpVtbl->SetMute(This,bMute,pguidEventContext)
#define IAudioEndpointVolumeEx_UnregisterControlChangeNotify(This,pNotify) (This)->lpVtbl->UnregisterControlChangeNotify(This,pNotify)
#define IAudioEndpointVolumeEx_VolumeStepDown(This,pguidEventContext) (This)->lpVtbl->VolumeStepDown(This,pguidEventContext)
#define IAudioEndpointVolumeEx_VolumeStepUp(This,pguidEventContext) (This)->lpVtbl->VolumeStepUp(This,pguidEventContext)
#define IAudioEndpointVolumeEx_GetVolumeRangeChannel(This,iChannel,pflVolumeMinDB,pflVolumeMaxDB,pflVolumeIncrementDB) (This)->lpVtbl->GetVolumeRangeChannel(This,iChannel,pflVolumeMinDB,pflVolumeMaxDB,pflVolumeIncrementDB)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IAudioInputEndpointRT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IAudioInputEndpointRT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IAudioInputEndpointRT methods */
    STDMETHOD(GetInputDataPointer)(THIS_ AE_CURRENT_POSITION *pAeTimeStamp) PURE;
    STDMETHOD(PulseEndpoint)(THIS) PURE;
    STDMETHOD(ReleaseInputDataPointer)(THIS_ UINT32 u32FrameCount,UINT_PTR pDataPointer) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IAudioInputEndpointRT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAudioInputEndpointRT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAudioInputEndpointRT_Release(This) (This)->lpVtbl->Release(This)
#define IAudioInputEndpointRT_GetInputDataPointer(This,pAeTimeStamp) (This)->lpVtbl->GetInputDataPointer(This,pAeTimeStamp)
#define IAudioInputEndpointRT_PulseEndpoint() (This)->lpVtbl->PulseEndpoint(This)
#define IAudioInputEndpointRT_ReleaseInputDataPointer(This,u32FrameCount,pDataPointer) (This)->lpVtbl->ReleaseInputDataPointer(This,u32FrameCount,pDataPointer)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IAudioOutputEndpointRT
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IAudioOutputEndpointRT,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IAudioOutputEndpointRT methods */
    STDMETHOD_(UINT_PTR,GetOutputDataPointer)(THIS_ UINT32 u32FrameCount,AE_CURRENT_POSITION *pAeTimeStamp) PURE;
    STDMETHOD(PulseEndpoint)(THIS) PURE;
    STDMETHOD(ReleaseOutputDataPointer)(THIS_ const APO_CONNECTION_PROPERTY *pConnectionProperty) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IAudioOutputEndpointRT_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAudioOutputEndpointRT_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAudioOutputEndpointRT_Release(This) (This)->lpVtbl->Release(This)
#define IAudioOutputEndpointRT_GetOutputDataPointer(This,u32FrameCount,pAeTimeStamp) (This)->lpVtbl->GetOutputDataPointer(This,u32FrameCount,pAeTimeStamp)
#define IAudioOutputEndpointRT_PulseEndpoint() (This)->lpVtbl->PulseEndpoint(This)
#define IAudioOutputEndpointRT_ReleaseOutputDataPointer(This,pConnectionProperty) (This)->lpVtbl->ReleaseOutputDataPointer(This,pConnectionProperty)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x0601)*/
#endif /*_INC_AUDIOENGINEENDPOINT*/
