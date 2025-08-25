/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __ipmsp_h__
#define __ipmsp_h__

#ifndef __ITParticipant_FWD_DEFINED__
#define __ITParticipant_FWD_DEFINED__
typedef struct ITParticipant ITParticipant;
#endif

#ifndef __ITFormatControl_FWD_DEFINED__
#define __ITFormatControl_FWD_DEFINED__
typedef struct ITFormatControl ITFormatControl;
#endif

#ifndef __ITStreamQualityControl_FWD_DEFINED__
#define __ITStreamQualityControl_FWD_DEFINED__
typedef struct ITStreamQualityControl ITStreamQualityControl;
#endif

#ifndef __ITCallQualityControl_FWD_DEFINED__
#define __ITCallQualityControl_FWD_DEFINED__
typedef struct ITCallQualityControl ITCallQualityControl;
#endif

#ifndef __ITAudioDeviceControl_FWD_DEFINED__
#define __ITAudioDeviceControl_FWD_DEFINED__
typedef struct ITAudioDeviceControl ITAudioDeviceControl;
#endif

#ifndef __ITAudioSettings_FWD_DEFINED__
#define __ITAudioSettings_FWD_DEFINED__
typedef struct ITAudioSettings ITAudioSettings;
#endif

#ifndef __ITQOSApplicationID_FWD_DEFINED__
#define __ITQOSApplicationID_FWD_DEFINED__
typedef struct ITQOSApplicationID ITQOSApplicationID;
#endif

#include "tapi3if.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define MAX_PARTICIPANT_TYPED_INFO_LENGTH (256)

#define MAX_QOS_ID_LEN (128)

  typedef enum PARTICIPANT_TYPED_INFO {
    PTI_CANONICALNAME = 0,PTI_NAME,PTI_EMAILADDRESS,PTI_PHONENUMBER,
    PTI_LOCATION,PTI_TOOL,PTI_NOTES,PTI_PRIVATE
  } PARTICIPANT_TYPED_INFO;

  typedef enum PARTICIPANT_EVENT {
    PE_NEW_PARTICIPANT = 0,PE_INFO_CHANGE,PE_PARTICIPANT_LEAVE,
    PE_NEW_SUBSTREAM,PE_SUBSTREAM_REMOVED,PE_SUBSTREAM_MAPPED,
    PE_SUBSTREAM_UNMAPPED,PE_PARTICIPANT_TIMEOUT,PE_PARTICIPANT_RECOVERED,
    PE_PARTICIPANT_ACTIVE,PE_PARTICIPANT_INACTIVE,PE_LOCAL_TALKING,
    PE_LOCAL_SILENT
  } PARTICIPANT_EVENT;

  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0000_v0_0_s_ifspec;

#ifndef __ITParticipant_INTERFACE_DEFINED__
#define __ITParticipant_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITParticipant;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITParticipant : public IDispatch {
  public:
    virtual HRESULT WINAPI get_ParticipantTypedInfo(PARTICIPANT_TYPED_INFO InfoType,BSTR *ppInfo) = 0;
    virtual HRESULT WINAPI get_MediaTypes(__LONG32 *plMediaType) = 0;
    virtual HRESULT WINAPI put_Status(ITStream *pITStream,VARIANT_BOOL fEnable) = 0;
    virtual HRESULT WINAPI get_Status(ITStream *pITStream,VARIANT_BOOL *pStatus) = 0;
    virtual HRESULT WINAPI get_Streams(VARIANT *pVariant) = 0;
    virtual HRESULT WINAPI EnumerateStreams(IEnumStream **ppEnumStream) = 0;
  };
#else
  typedef struct ITParticipantVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITParticipant *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITParticipant *This);
      ULONG (WINAPI *Release)(ITParticipant *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITParticipant *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITParticipant *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITParticipant *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITParticipant *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_ParticipantTypedInfo)(ITParticipant *This,PARTICIPANT_TYPED_INFO InfoType,BSTR *ppInfo);
      HRESULT (WINAPI *get_MediaTypes)(ITParticipant *This,__LONG32 *plMediaType);
      HRESULT (WINAPI *put_Status)(ITParticipant *This,ITStream *pITStream,VARIANT_BOOL fEnable);
      HRESULT (WINAPI *get_Status)(ITParticipant *This,ITStream *pITStream,VARIANT_BOOL *pStatus);
      HRESULT (WINAPI *get_Streams)(ITParticipant *This,VARIANT *pVariant);
      HRESULT (WINAPI *EnumerateStreams)(ITParticipant *This,IEnumStream **ppEnumStream);
    END_INTERFACE
  } ITParticipantVtbl;
  struct ITParticipant {
    CONST_VTBL struct ITParticipantVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITParticipant_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITParticipant_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITParticipant_Release(This) (This)->lpVtbl->Release(This)
#define ITParticipant_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITParticipant_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITParticipant_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITParticipant_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITParticipant_get_ParticipantTypedInfo(This,InfoType,ppInfo) (This)->lpVtbl->get_ParticipantTypedInfo(This,InfoType,ppInfo)
#define ITParticipant_get_MediaTypes(This,plMediaType) (This)->lpVtbl->get_MediaTypes(This,plMediaType)
#define ITParticipant_put_Status(This,pITStream,fEnable) (This)->lpVtbl->put_Status(This,pITStream,fEnable)
#define ITParticipant_get_Status(This,pITStream,pStatus) (This)->lpVtbl->get_Status(This,pITStream,pStatus)
#define ITParticipant_get_Streams(This,pVariant) (This)->lpVtbl->get_Streams(This,pVariant)
#define ITParticipant_EnumerateStreams(This,ppEnumStream) (This)->lpVtbl->EnumerateStreams(This,ppEnumStream)
#endif
#endif
  HRESULT WINAPI ITParticipant_get_ParticipantTypedInfo_Proxy(ITParticipant *This,PARTICIPANT_TYPED_INFO InfoType,BSTR *ppInfo);
  void __RPC_STUB ITParticipant_get_ParticipantTypedInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipant_get_MediaTypes_Proxy(ITParticipant *This,__LONG32 *plMediaType);
  void __RPC_STUB ITParticipant_get_MediaTypes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipant_put_Status_Proxy(ITParticipant *This,ITStream *pITStream,VARIANT_BOOL fEnable);
  void __RPC_STUB ITParticipant_put_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipant_get_Status_Proxy(ITParticipant *This,ITStream *pITStream,VARIANT_BOOL *pStatus);
  void __RPC_STUB ITParticipant_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipant_get_Streams_Proxy(ITParticipant *This,VARIANT *pVariant);
  void __RPC_STUB ITParticipant_get_Streams_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITParticipant_EnumerateStreams_Proxy(ITParticipant *This,IEnumStream **ppEnumStream);
  void __RPC_STUB ITParticipant_EnumerateStreams_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef STREAM_INTERFACES_DEFINED
#define STREAM_INTERFACES_DEFINED
#define MAX_DESCRIPTION_LEN (256)
  typedef struct _TAPI_AUDIO_STREAM_CONFIG_CAPS {
    WCHAR Description[256 ];
    ULONG MinimumChannels;
    ULONG MaximumChannels;
    ULONG ChannelsGranularity;
    ULONG MinimumBitsPerSample;
    ULONG MaximumBitsPerSample;
    ULONG BitsPerSampleGranularity;
    ULONG MinimumSampleFrequency;
    ULONG MaximumSampleFrequency;
    ULONG SampleFrequencyGranularity;
    ULONG MinimumAvgBytesPerSec;
    ULONG MaximumAvgBytesPerSec;
    ULONG AvgBytesPerSecGranularity;
  } TAPI_AUDIO_STREAM_CONFIG_CAPS;

  typedef struct _TAPI_AUDIO_STREAM_CONFIG_CAPS *PTAPI_AUDIO_STREAM_CONFIG_CAPS;

  typedef struct _TAPI_VIDEO_STREAM_CONFIG_CAPS {
    WCHAR Description[256 ];
    ULONG VideoStandard;
    SIZE InputSize;
    SIZE MinCroppingSize;
    SIZE MaxCroppingSize;
    int CropGranularityX;
    int CropGranularityY;
    int CropAlignX;
    int CropAlignY;
    SIZE MinOutputSize;
    SIZE MaxOutputSize;
    int OutputGranularityX;
    int OutputGranularityY;
    int StretchTapsX;
    int StretchTapsY;
    int ShrinkTapsX;
    int ShrinkTapsY;
    LONGLONG MinFrameInterval;
    LONGLONG MaxFrameInterval;
    LONG MinBitsPerSecond;
    LONG MaxBitsPerSecond;
  } TAPI_VIDEO_STREAM_CONFIG_CAPS;

  typedef struct _TAPI_VIDEO_STREAM_CONFIG_CAPS *PTAPI_VIDEO_STREAM_CONFIG_CAPS;

  typedef enum tagStreamConfigCapsType {
    AudioStreamConfigCaps = 0,VideoStreamConfigCaps = AudioStreamConfigCaps + 1
  } StreamConfigCapsType;

  typedef struct tagTAPI_STREAM_CONFIG_CAPS {
    StreamConfigCapsType CapsType;
    __C89_NAMELESS union {
      TAPI_VIDEO_STREAM_CONFIG_CAPS VideoCap;
      TAPI_AUDIO_STREAM_CONFIG_CAPS AudioCap;
    };
  } TAPI_STREAM_CONFIG_CAPS;

  typedef struct tagTAPI_STREAM_CONFIG_CAPS *PTAPI_STREAM_CONFIG_CAPS;

  typedef enum tagTAPIControlFlags {
    TAPIControl_Flags_None = 0,TAPIControl_Flags_Auto = 0x1,TAPIControl_Flags_Manual = 0x2
  } TAPIControlFlags;

  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0502_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0502_v0_0_s_ifspec;

#ifndef __ITFormatControl_INTERFACE_DEFINED__
#define __ITFormatControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITFormatControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITFormatControl : public IUnknown {
  public:
    virtual HRESULT WINAPI GetCurrentFormat(AM_MEDIA_TYPE **ppMediaType) = 0;
    virtual HRESULT WINAPI ReleaseFormat(AM_MEDIA_TYPE *pMediaType) = 0;
    virtual HRESULT WINAPI GetNumberOfCapabilities(DWORD *pdwCount) = 0;
    virtual HRESULT WINAPI GetStreamCaps(DWORD dwIndex,AM_MEDIA_TYPE **ppMediaType,TAPI_STREAM_CONFIG_CAPS *pStreamConfigCaps,WINBOOL *pfEnabled) = 0;
    virtual HRESULT WINAPI ReOrderCapabilities(DWORD *pdwIndices,WINBOOL *pfEnabled,WINBOOL *pfPublicize,DWORD dwNumIndices) = 0;
  };
#else
  typedef struct ITFormatControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITFormatControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITFormatControl *This);
      ULONG (WINAPI *Release)(ITFormatControl *This);
      HRESULT (WINAPI *GetCurrentFormat)(ITFormatControl *This,AM_MEDIA_TYPE **ppMediaType);
      HRESULT (WINAPI *ReleaseFormat)(ITFormatControl *This,AM_MEDIA_TYPE *pMediaType);
      HRESULT (WINAPI *GetNumberOfCapabilities)(ITFormatControl *This,DWORD *pdwCount);
      HRESULT (WINAPI *GetStreamCaps)(ITFormatControl *This,DWORD dwIndex,AM_MEDIA_TYPE **ppMediaType,TAPI_STREAM_CONFIG_CAPS *pStreamConfigCaps,WINBOOL *pfEnabled);
      HRESULT (WINAPI *ReOrderCapabilities)(ITFormatControl *This,DWORD *pdwIndices,WINBOOL *pfEnabled,WINBOOL *pfPublicize,DWORD dwNumIndices);
    END_INTERFACE
  } ITFormatControlVtbl;
  struct ITFormatControl {
    CONST_VTBL struct ITFormatControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITFormatControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITFormatControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITFormatControl_Release(This) (This)->lpVtbl->Release(This)
#define ITFormatControl_GetCurrentFormat(This,ppMediaType) (This)->lpVtbl->GetCurrentFormat(This,ppMediaType)
#define ITFormatControl_ReleaseFormat(This,pMediaType) (This)->lpVtbl->ReleaseFormat(This,pMediaType)
#define ITFormatControl_GetNumberOfCapabilities(This,pdwCount) (This)->lpVtbl->GetNumberOfCapabilities(This,pdwCount)
#define ITFormatControl_GetStreamCaps(This,dwIndex,ppMediaType,pStreamConfigCaps,pfEnabled) (This)->lpVtbl->GetStreamCaps(This,dwIndex,ppMediaType,pStreamConfigCaps,pfEnabled)
#define ITFormatControl_ReOrderCapabilities(This,pdwIndices,pfEnabled,pfPublicize,dwNumIndices) (This)->lpVtbl->ReOrderCapabilities(This,pdwIndices,pfEnabled,pfPublicize,dwNumIndices)
#endif
#endif
  HRESULT WINAPI ITFormatControl_GetCurrentFormat_Proxy(ITFormatControl *This,AM_MEDIA_TYPE **ppMediaType);
  void __RPC_STUB ITFormatControl_GetCurrentFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFormatControl_ReleaseFormat_Proxy(ITFormatControl *This,AM_MEDIA_TYPE *pMediaType);
  void __RPC_STUB ITFormatControl_ReleaseFormat_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFormatControl_GetNumberOfCapabilities_Proxy(ITFormatControl *This,DWORD *pdwCount);
  void __RPC_STUB ITFormatControl_GetNumberOfCapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFormatControl_GetStreamCaps_Proxy(ITFormatControl *This,DWORD dwIndex,AM_MEDIA_TYPE **ppMediaType,TAPI_STREAM_CONFIG_CAPS *pStreamConfigCaps,WINBOOL *pfEnabled);
  void __RPC_STUB ITFormatControl_GetStreamCaps_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITFormatControl_ReOrderCapabilities_Proxy(ITFormatControl *This,DWORD *pdwIndices,WINBOOL *pfEnabled,WINBOOL *pfPublicize,DWORD dwNumIndices);
  void __RPC_STUB ITFormatControl_ReOrderCapabilities_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum tagStreamQualityProperty {
    StreamQuality_MaxBitrate = 0,StreamQuality_CurrBitrate,StreamQuality_MinFrameInterval,
    StreamQuality_AvgFrameInterval
  } StreamQualityProperty;

  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0503_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0503_v0_0_s_ifspec;

#ifndef __ITStreamQualityControl_INTERFACE_DEFINED__
#define __ITStreamQualityControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITStreamQualityControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITStreamQualityControl : public IUnknown {
  public:
    virtual HRESULT WINAPI GetRange(StreamQualityProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags) = 0;
    virtual HRESULT WINAPI Get(StreamQualityProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags) = 0;
    virtual HRESULT WINAPI Set(StreamQualityProperty Property,__LONG32 lValue,TAPIControlFlags lFlags) = 0;
  };
#else
  typedef struct ITStreamQualityControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITStreamQualityControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITStreamQualityControl *This);
      ULONG (WINAPI *Release)(ITStreamQualityControl *This);
      HRESULT (WINAPI *GetRange)(ITStreamQualityControl *This,StreamQualityProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags);
      HRESULT (WINAPI *Get)(ITStreamQualityControl *This,StreamQualityProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags);
      HRESULT (WINAPI *Set)(ITStreamQualityControl *This,StreamQualityProperty Property,__LONG32 lValue,TAPIControlFlags lFlags);
    END_INTERFACE
  } ITStreamQualityControlVtbl;
  struct ITStreamQualityControl {
    CONST_VTBL struct ITStreamQualityControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITStreamQualityControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITStreamQualityControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITStreamQualityControl_Release(This) (This)->lpVtbl->Release(This)
#define ITStreamQualityControl_GetRange(This,Property,plMin,plMax,plSteppingDelta,plDefault,plFlags) (This)->lpVtbl->GetRange(This,Property,plMin,plMax,plSteppingDelta,plDefault,plFlags)
#define ITStreamQualityControl_Get(This,Property,plValue,plFlags) (This)->lpVtbl->Get(This,Property,plValue,plFlags)
#define ITStreamQualityControl_Set(This,Property,lValue,lFlags) (This)->lpVtbl->Set(This,Property,lValue,lFlags)
#endif
#endif
  HRESULT WINAPI ITStreamQualityControl_GetRange_Proxy(ITStreamQualityControl *This,StreamQualityProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags);
  void __RPC_STUB ITStreamQualityControl_GetRange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStreamQualityControl_Get_Proxy(ITStreamQualityControl *This,StreamQualityProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags);
  void __RPC_STUB ITStreamQualityControl_Get_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITStreamQualityControl_Set_Proxy(ITStreamQualityControl *This,StreamQualityProperty Property,__LONG32 lValue,TAPIControlFlags lFlags);
  void __RPC_STUB ITStreamQualityControl_Set_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum tagCallQualityProperty {
    CallQuality_ControlInterval = 0,CallQuality_ConfBitrate,CallQuality_MaxInputBitrate,
    CallQuality_CurrInputBitrate,CallQuality_MaxOutputBitrate,
    CallQuality_CurrOutputBitrate,CallQuality_MaxCPULoad,CallQuality_CurrCPULoad
  } CallQualityProperty;

  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0504_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0504_v0_0_s_ifspec;

#ifndef __ITCallQualityControl_INTERFACE_DEFINED__
#define __ITCallQualityControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITCallQualityControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITCallQualityControl : public IUnknown {
  public:
    virtual HRESULT WINAPI GetRange(CallQualityProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags) = 0;
    virtual HRESULT WINAPI Get(CallQualityProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags) = 0;
    virtual HRESULT WINAPI Set(CallQualityProperty Property,__LONG32 lValue,TAPIControlFlags lFlags) = 0;
  };
#else
  typedef struct ITCallQualityControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITCallQualityControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITCallQualityControl *This);
      ULONG (WINAPI *Release)(ITCallQualityControl *This);
      HRESULT (WINAPI *GetRange)(ITCallQualityControl *This,CallQualityProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags);
      HRESULT (WINAPI *Get)(ITCallQualityControl *This,CallQualityProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags);
      HRESULT (WINAPI *Set)(ITCallQualityControl *This,CallQualityProperty Property,__LONG32 lValue,TAPIControlFlags lFlags);
    END_INTERFACE
  } ITCallQualityControlVtbl;
  struct ITCallQualityControl {
    CONST_VTBL struct ITCallQualityControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITCallQualityControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITCallQualityControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITCallQualityControl_Release(This) (This)->lpVtbl->Release(This)
#define ITCallQualityControl_GetRange(This,Property,plMin,plMax,plSteppingDelta,plDefault,plFlags) (This)->lpVtbl->GetRange(This,Property,plMin,plMax,plSteppingDelta,plDefault,plFlags)
#define ITCallQualityControl_Get(This,Property,plValue,plFlags) (This)->lpVtbl->Get(This,Property,plValue,plFlags)
#define ITCallQualityControl_Set(This,Property,lValue,lFlags) (This)->lpVtbl->Set(This,Property,lValue,lFlags)
#endif
#endif
  HRESULT WINAPI ITCallQualityControl_GetRange_Proxy(ITCallQualityControl *This,CallQualityProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags);
  void __RPC_STUB ITCallQualityControl_GetRange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallQualityControl_Get_Proxy(ITCallQualityControl *This,CallQualityProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags);
  void __RPC_STUB ITCallQualityControl_Get_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITCallQualityControl_Set_Proxy(ITCallQualityControl *This,CallQualityProperty Property,__LONG32 lValue,TAPIControlFlags lFlags);
  void __RPC_STUB ITCallQualityControl_Set_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum tagAudioDeviceProperty {
    AudioDevice_DuplexMode = 0,AudioDevice_AutomaticGainControl,
    AudioDevice_AcousticEchoCancellation
  } AudioDeviceProperty;

  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0505_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0505_v0_0_s_ifspec;

#ifndef __ITAudioDeviceControl_INTERFACE_DEFINED__
#define __ITAudioDeviceControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAudioDeviceControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAudioDeviceControl : public IUnknown {
  public:
    virtual HRESULT WINAPI GetRange(AudioDeviceProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags) = 0;
    virtual HRESULT WINAPI Get(AudioDeviceProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags) = 0;
    virtual HRESULT WINAPI Set(AudioDeviceProperty Property,__LONG32 lValue,TAPIControlFlags lFlags) = 0;
  };
#else
  typedef struct ITAudioDeviceControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAudioDeviceControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAudioDeviceControl *This);
      ULONG (WINAPI *Release)(ITAudioDeviceControl *This);
      HRESULT (WINAPI *GetRange)(ITAudioDeviceControl *This,AudioDeviceProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags);
      HRESULT (WINAPI *Get)(ITAudioDeviceControl *This,AudioDeviceProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags);
      HRESULT (WINAPI *Set)(ITAudioDeviceControl *This,AudioDeviceProperty Property,__LONG32 lValue,TAPIControlFlags lFlags);
    END_INTERFACE
  } ITAudioDeviceControlVtbl;
  struct ITAudioDeviceControl {
    CONST_VTBL struct ITAudioDeviceControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAudioDeviceControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAudioDeviceControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAudioDeviceControl_Release(This) (This)->lpVtbl->Release(This)
#define ITAudioDeviceControl_GetRange(This,Property,plMin,plMax,plSteppingDelta,plDefault,plFlags) (This)->lpVtbl->GetRange(This,Property,plMin,plMax,plSteppingDelta,plDefault,plFlags)
#define ITAudioDeviceControl_Get(This,Property,plValue,plFlags) (This)->lpVtbl->Get(This,Property,plValue,plFlags)
#define ITAudioDeviceControl_Set(This,Property,lValue,lFlags) (This)->lpVtbl->Set(This,Property,lValue,lFlags)
#endif
#endif
  HRESULT WINAPI ITAudioDeviceControl_GetRange_Proxy(ITAudioDeviceControl *This,AudioDeviceProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags);
  void __RPC_STUB ITAudioDeviceControl_GetRange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAudioDeviceControl_Get_Proxy(ITAudioDeviceControl *This,AudioDeviceProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags);
  void __RPC_STUB ITAudioDeviceControl_Get_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAudioDeviceControl_Set_Proxy(ITAudioDeviceControl *This,AudioDeviceProperty Property,__LONG32 lValue,TAPIControlFlags lFlags);
  void __RPC_STUB ITAudioDeviceControl_Set_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum tagAudioSettingsProperty {
    AudioSettings_SignalLevel = 0,AudioSettings_SilenceThreshold,
    AudioSettings_Volume,AudioSettings_Balance,AudioSettings_Loudness,
    AudioSettings_Treble,AudioSettings_Bass,AudioSettings_Mono
  } AudioSettingsProperty;

  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0506_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0506_v0_0_s_ifspec;

#ifndef __ITAudioSettings_INTERFACE_DEFINED__
#define __ITAudioSettings_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAudioSettings;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAudioSettings : public IUnknown {
  public:
    virtual HRESULT WINAPI GetRange(AudioSettingsProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags) = 0;
    virtual HRESULT WINAPI Get(AudioSettingsProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags) = 0;
    virtual HRESULT WINAPI Set(AudioSettingsProperty Property,__LONG32 lValue,TAPIControlFlags lFlags) = 0;
  };
#else
  typedef struct ITAudioSettingsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAudioSettings *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAudioSettings *This);
      ULONG (WINAPI *Release)(ITAudioSettings *This);
      HRESULT (WINAPI *GetRange)(ITAudioSettings *This,AudioSettingsProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags);
      HRESULT (WINAPI *Get)(ITAudioSettings *This,AudioSettingsProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags);
      HRESULT (WINAPI *Set)(ITAudioSettings *This,AudioSettingsProperty Property,__LONG32 lValue,TAPIControlFlags lFlags);
    END_INTERFACE
  } ITAudioSettingsVtbl;
  struct ITAudioSettings {
    CONST_VTBL struct ITAudioSettingsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAudioSettings_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAudioSettings_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAudioSettings_Release(This) (This)->lpVtbl->Release(This)
#define ITAudioSettings_GetRange(This,Property,plMin,plMax,plSteppingDelta,plDefault,plFlags) (This)->lpVtbl->GetRange(This,Property,plMin,plMax,plSteppingDelta,plDefault,plFlags)
#define ITAudioSettings_Get(This,Property,plValue,plFlags) (This)->lpVtbl->Get(This,Property,plValue,plFlags)
#define ITAudioSettings_Set(This,Property,lValue,lFlags) (This)->lpVtbl->Set(This,Property,lValue,lFlags)
#endif
#endif
  HRESULT WINAPI ITAudioSettings_GetRange_Proxy(ITAudioSettings *This,AudioSettingsProperty Property,__LONG32 *plMin,__LONG32 *plMax,__LONG32 *plSteppingDelta,__LONG32 *plDefault,TAPIControlFlags *plFlags);
  void __RPC_STUB ITAudioSettings_GetRange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAudioSettings_Get_Proxy(ITAudioSettings *This,AudioSettingsProperty Property,__LONG32 *plValue,TAPIControlFlags *plFlags);
  void __RPC_STUB ITAudioSettings_Get_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAudioSettings_Set_Proxy(ITAudioSettings *This,AudioSettingsProperty Property,__LONG32 lValue,TAPIControlFlags lFlags);
  void __RPC_STUB ITAudioSettings_Set_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITQOSApplicationID_INTERFACE_DEFINED__
#define __ITQOSApplicationID_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITQOSApplicationID;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITQOSApplicationID : public IDispatch {
  public:
    virtual HRESULT WINAPI SetQOSApplicationID(BSTR pApplicationID,BSTR pApplicationGUID,BSTR pSubIDs) = 0;
  };
#else
  typedef struct ITQOSApplicationIDVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITQOSApplicationID *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITQOSApplicationID *This);
      ULONG (WINAPI *Release)(ITQOSApplicationID *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITQOSApplicationID *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITQOSApplicationID *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITQOSApplicationID *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITQOSApplicationID *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetQOSApplicationID)(ITQOSApplicationID *This,BSTR pApplicationID,BSTR pApplicationGUID,BSTR pSubIDs);
    END_INTERFACE
  } ITQOSApplicationIDVtbl;
  struct ITQOSApplicationID {
    CONST_VTBL struct ITQOSApplicationIDVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITQOSApplicationID_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITQOSApplicationID_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITQOSApplicationID_Release(This) (This)->lpVtbl->Release(This)
#define ITQOSApplicationID_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITQOSApplicationID_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITQOSApplicationID_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITQOSApplicationID_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITQOSApplicationID_SetQOSApplicationID(This,pApplicationID,pApplicationGUID,pSubIDs) (This)->lpVtbl->SetQOSApplicationID(This,pApplicationID,pApplicationGUID,pSubIDs)
#endif
#endif
  HRESULT WINAPI ITQOSApplicationID_SetQOSApplicationID_Proxy(ITQOSApplicationID *This,BSTR pApplicationID,BSTR pApplicationGUID,BSTR pSubIDs);
  void __RPC_STUB ITQOSApplicationID_SetQOSApplicationID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifndef RTP_MEDIATYPE_DEFINED
#define RTP_MEDIATYPE_DEFINED
  struct MEDIATYPE_RTP_Single_Stream;
#endif
  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0508_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_ipmsp_0508_v0_0_s_ifspec;

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
